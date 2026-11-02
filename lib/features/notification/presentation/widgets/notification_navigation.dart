import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'dart:async';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:petlytics/features/feeding/presentation/cubit/feeding_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/error/failure.dart';
import 'package:petlytics/core/result/result.dart';
import 'package:petlytics/core/router/app_navigation_observer.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_cubit.dart';
import 'package:petlytics/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:petlytics/features/notification/domain/entities/notification_target.dart';
import 'package:petlytics/features/notification/domain/use_cases/resolve_notification_target.dart';
import 'package:petlytics/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:petlytics/features/notification/presentation/cubit/notification_state.dart';

class NotificationNavigation extends StatefulWidget {
  final GoRouter router;
  final List<AppNavigationObserver> observers;
  final Listenable routeChanges;
  final ResolveNotificationTarget resolve;
  final Widget child;
  const NotificationNavigation({
    super.key,
    required this.router,
    required this.observers,
    required this.routeChanges,
    required this.resolve,
    required this.child,
  });
  @override
  State<NotificationNavigation> createState() => _NotificationNavigationState();
}

class _NotificationNavigationState extends State<NotificationNavigation>
    with WidgetsBindingObserver {
  bool _scheduled = false;
  bool _opening = false;
  NotificationTarget? _deferred;
  AllPetsCareCubit? _global;
  StreamSubscription<AllPetsCareState>? _globalWrites;
  FeedingCubit? _feeding;
  StreamSubscription<FeedingState>? _feedingWrites;
  NotificationCubit get _cubit => context.read<NotificationCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.routeChanges.addListener(_schedule);
    widget.router.routerDelegate.addListener(_schedule);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  bool get _blocked {
    final path = widget.router.state.uri.path;
    if (path.endsWith('/form') ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return true;
    }
    for (final observer in widget.observers) {
      final route = observer.topRoute;
      if (route == null || !route.isCurrent || !route.isActive) continue;
      if (route is PopupRoute) return true;
      if (route.popDisposition == RoutePopDisposition.doNotPop) {
        // The global care tabs handle Back themselves even when they are idle.
        final global = route is ModalRoute
            ? route.subtreeContext?.read<AllPetsCareCubit?>()
            : null;
        final feeding = path == AppRoutes.allFeeding && route is ModalRoute
            ? route.subtreeContext?.read<FeedingCubit?>()
            : null;
        if (feeding != null &&
            feeding.state is FeedingLoaded &&
            (feeding.state as FeedingLoaded).pendingAction != null) {
          if (_feeding != feeding) {
            _feedingWrites?.cancel();
            _feeding = feeding;
            _feedingWrites = feeding.stream.listen((_) => _schedule());
          }
          return true;
        }
        if (global != null && _global != global && global.state.isBusy) {
          _globalWrites?.cancel();
          _global = global;
          _globalWrites = global.stream.listen((_) => _schedule());
        }
        if ([
              AppRoutes.pets,
              AppRoutes.allVetVisits,
              AppRoutes.allVaccinations,
              AppRoutes.allMedications,
              AppRoutes.allFeeding,
            ].contains(path) &&
            global != null &&
            !global.state.isBusy) {
          continue;
        }
        return true;
      }
    }
    return false;
  }

  void _schedule() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _opening) return;
      final target = _cubit.state.pendingTarget;
      if (target == null) return;
      if (_blocked) {
        if (_deferred != target &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          _deferred = target;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).finishFormToOpenReminder,
              ),
            ),
          );
        }
        return;
      }
      unawaited(_open(target));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _open(NotificationTarget target) async {
    _opening = true;
    try {
      final result = await widget.resolve(target);
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _cubit.state.pendingTarget != target || _blocked) return;
      _cubit.acknowledgeTarget();
      _globalWrites?.cancel();
      _feedingWrites?.cancel();
      _feedingWrites = null;
      _feeding = null;
      _globalWrites = null;
      _global = null;
      _deferred = null;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      switch (result) {
        case Error(:final failure):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                failure is NotFoundFailure
                    ? AppLocalizations.of(context).reminderTargetUnavailable
                    : AppLocalizations.of(context).reminderOpenFailed,
              ),
              action: failure is NotFoundFailure
                  ? null
                  : SnackBarAction(
                      label: AppLocalizations.of(context).retry,
                      onPressed: () => _cubit.requestOpen(target),
                    ),
            ),
          );
        case Success():
          switch (target) {
            case FeedingMealNotificationTarget():
              final location = AppRoutes.feeding(target.petId);
              final extra = FeedingRouteExtra(
                petId: target.petId,
                petName: result.data.name,
                date: target.scheduledDate,
              );
              final current = widget.router.state.uri.path;
              if (current == AppRoutes.petDetail(target.petId) ||
                  current.startsWith('${AppRoutes.petDetail(target.petId)}/')) {
                widget.router.go(location, extra: extra);
              } else {
                unawaited(widget.router.push<void>(location, extra: extra));
              }
            case VaccinationNotificationTarget():
              unawaited(
                widget.router.push<void>(
                  AppRoutes.vaccinationDetail(
                    target.petId,
                    target.vaccinationId,
                  ),
                  extra: PetCareRouteExtra(
                    petId: target.petId,
                    petName: result.data.name,
                  ),
                ),
              );
            case MedicationDoseNotificationTarget():
              unawaited(
                widget.router.push<void>(
                  AppRoutes.medicationDetail(target.petId, target.medicationId),
                  extra: MedicationDetailExtra(
                    petId: target.petId,
                    petName: result.data.name,
                    medicationId: target.medicationId,
                    doseDate: target.scheduledDate,
                  ),
                ),
              );
          }
      }
    } finally {
      _opening = false;
      if (mounted) _schedule();
    }
  }

  @override
  void dispose() {
    _feedingWrites?.cancel();
    _globalWrites?.cancel();
    widget.routeChanges.removeListener(_schedule);
    widget.router.routerDelegate.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<NotificationCubit, NotificationState>(
        listenWhen: (previous, current) =>
            previous.pendingTarget != current.pendingTarget,
        listener: (_, _) => _schedule(),
        child: NotificationListener<NavigationNotification>(
          onNotification: (_) {
            _schedule();
            return false;
          },
          child: widget.child,
        ),
      );
}
