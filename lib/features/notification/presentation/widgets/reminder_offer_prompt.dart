import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/router/app_navigation_observer.dart';
import 'package:patilog/core/widgets/app_confirmation_dialog.dart';
import 'package:patilog/features/notification/domain/entities/reminder_category.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_state.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

/// Shows a pending reminder offer once the saving form has closed and no other
/// popup is open, so the offer never covers an unfinished form or dialog.
class ReminderOfferPrompt extends StatefulWidget {
  final GoRouter router;
  final List<AppNavigationObserver> observers;
  final Listenable routeChanges;
  final Widget child;
  const ReminderOfferPrompt({
    super.key,
    required this.router,
    required this.observers,
    required this.routeChanges,
    required this.child,
  });

  @override
  State<ReminderOfferPrompt> createState() => _ReminderOfferPromptState();
}

class _ReminderOfferPromptState extends State<ReminderOfferPrompt>
    with WidgetsBindingObserver {
  bool _scheduled = false;
  bool _showing = false;
  NotificationCubit get _cubit => context.read<NotificationCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.routeChanges.addListener(_schedule);
    widget.router.routerDelegate.addListener(_schedule);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  bool get _blocked {
    if (widget.router.state.uri.path.endsWith('/form') ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return true;
    }
    for (final observer in widget.observers) {
      final route = observer.topRoute;
      if (route is PopupRoute && route.isActive) return true;
    }
    return false;
  }

  void _schedule() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _showing || _cubit.state.reminderOffer == null) return;
      // Route and lifecycle changes schedule another check when unblocked.
      if (!_blocked) unawaited(_show(_cubit.state.reminderOffer!));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _show(ReminderCategory category) async {
    final navigator = widget.router.routerDelegate.navigatorKey.currentContext;
    if (navigator == null) return;
    _showing = true;
    final bool? accepted;
    try {
      accepted = await showDialog<bool>(
        context: navigator,
        builder: (context) {
          final s = AppLocalizations.of(context);
          return AppConfirmationDialog(
            title: switch (category) {
              ReminderCategory.medication => s.reminderOfferMedicationTitle,
              ReminderCategory.vaccination => s.reminderOfferVaccinationTitle,
              ReminderCategory.feeding => s.reminderOfferFeedingTitle,
            },
            message: switch (category) {
              ReminderCategory.medication => s.reminderOfferMedicationMessage,
              ReminderCategory.vaccination => s.reminderOfferVaccinationMessage,
              ReminderCategory.feeding => s.reminderOfferFeedingMessage,
            },
            cancelLabel: s.reminderOfferNotNow,
            confirmLabel: s.reminderOfferTurnOn,
          );
        },
      );
    } finally {
      _showing = false;
    }
    if (!mounted) return;
    // Back and barrier taps decline like "Not now".
    await _cubit.answerReminderOffer(accepted: accepted == true);
    if (!mounted) return;
    if (accepted == true) _report();
    _schedule();
  }

  /// Blocked notifications are explained by ReminderBlockedNotice on the
  /// screen the saved record returns to; only a failed save needs feedback.
  void _report() {
    if (_cubit.state.saveError == null) return;
    final s = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s.reminderSettingsSaveFailed),
          action: SnackBarAction(label: s.retry, onPressed: _retry),
        ),
      );
  }

  Future<void> _retry() async {
    await _cubit.retrySave();
    if (mounted) _report();
  }

  @override
  void dispose() {
    widget.routeChanges.removeListener(_schedule);
    widget.router.routerDelegate.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<NotificationCubit, NotificationState>(
        listenWhen: (previous, current) =>
            previous.reminderOffer != current.reminderOffer,
        listener: (_, _) => _schedule(),
        child: widget.child,
      );
}
