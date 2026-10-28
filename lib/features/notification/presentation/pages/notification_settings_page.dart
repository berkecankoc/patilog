import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_form_actions.dart';
import 'package:petlytics/core/widgets/app_form_scroll_view.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/features/notification/domain/entities/notification_preferences.dart';
import 'package:petlytics/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:petlytics/features/notification/presentation/cubit/notification_state.dart';
import 'package:petlytics/features/notification/presentation/widgets/reminder_schedule_fields.dart';
import 'package:petlytics/features/notification/domain/entities/vaccination_reminder_schedule.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  NotificationPreferences _preferences(
    NotificationCubit cubit, {
    bool? medication,
    bool? vaccination,
    VaccinationReminderSchedule? schedule,
  }) {
    final current = cubit.state.preferences!;
    return NotificationPreferences(
      medicationRemindersEnabled:
          medication ?? current.medicationRemindersEnabled,
      vaccinationRemindersEnabled:
          vaccination ?? current.vaccinationRemindersEnabled,
      vaccinationSchedule: schedule ?? current.vaccinationSchedule,
    );
  }

  Future<void> _editSchedule(BuildContext context) async {
    final cubit = context.read<NotificationCubit>();
    if (cubit.state.isBusy || cubit.state.preferences == null) return;
    final schedule = await showModalBottomSheet<VaccinationReminderSchedule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _ScheduleEditor(
        initial: cubit.state.preferences!.vaccinationSchedule,
      ),
    );
    if (schedule != null &&
        context.mounted &&
        cubit.state.preferences != null) {
      await cubit.setPreferences(_preferences(cubit, schedule: schedule));
    }
  }

  Widget _reminderToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 320 &&
          MediaQuery.textScalerOf(context).scale(16) > 20;
      if (!compact) {
        return SwitchListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          secondary: Icon(icon),
          value: value,
          onChanged: onChanged,
        );
      }
      return MergeSemantics(
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(subtitle),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Switch(value: value, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<NotificationCubit, NotificationState>(
    builder: (context, state) {
      final cubit = context.read<NotificationCubit>();
      final preferences = state.preferences;
      final enabled = preferences != null && !state.isBusy;
      final anyOn =
          preferences?.medicationRemindersEnabled == true ||
          preferences?.vaccinationRemindersEnabled == true;
      final blocked = anyOn && state.permissions?.canShowNotifications == false;
      final inexact =
          preferences?.medicationRemindersEnabled == true &&
          state.permissions?.canShowNotifications == true &&
          state.permissions?.requiresExactAlarmPermission == true &&
          state.permissions?.canScheduleExactAlarms == false;
      void back() {
        if (cubit.state.isSaving) return;
        context.canPop() ? context.pop() : context.go(AppRoutes.settings);
      }

      return PopScope(
        canPop: !state.isSaving,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            leading: state.isSaving
                ? IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: null,
                    icon: const BackButtonIcon(),
                  )
                : BackButton(onPressed: back),
            bottom: state.isBusy
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Updating reminders',
                    ),
                  )
                : null,
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  if (state.saveError != null || state.issue != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.5,
                      ),
                      child: AppErrorFeedback(
                        message: state.saveError ?? state.issue!.message,
                        retryLabel: state.saveError != null
                            ? 'Retry save'
                            : 'Retry',
                        onRetry: state.isBusy
                            ? null
                            : state.saveError != null
                            ? cubit.retrySave
                            : cubit.retry,
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          children: [
                            const AppSectionHeading(
                              title: 'Reminders',
                              icon: Icons.notifications_outlined,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'Choose which reminders this device sends. Times follow the device’s local time.',
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Card(
                              margin: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  _reminderToggle(
                                    title: 'Medication reminders',
                                    subtitle: 'At scheduled dose times.',
                                    icon: Icons.medication_outlined,
                                    value:
                                        preferences
                                            ?.medicationRemindersEnabled ??
                                        false,
                                    onChanged: enabled
                                        ? (value) => cubit.setPreferences(
                                            _preferences(
                                              cubit,
                                              medication: value,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const Divider(
                                    height: 1,
                                    indent: AppSpacing.md,
                                    endIndent: AppSpacing.md,
                                  ),
                                  _reminderToggle(
                                    title: 'Vaccination reminders',
                                    subtitle: 'On selected days.',
                                    icon: Icons.vaccines_outlined,
                                    value:
                                        preferences
                                            ?.vaccinationRemindersEnabled ??
                                        false,
                                    onChanged: enabled
                                        ? (value) => cubit.setPreferences(
                                            _preferences(
                                              cubit,
                                              vaccination: value,
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const AppSectionHeading(
                              title: 'Vaccination schedule',
                              icon: Icons.schedule_outlined,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                title: const Text('Days & time'),
                                subtitle: Text(
                                  preferences == null
                                      ? state.issue == null
                                            ? 'Loading schedule…'
                                            : 'Schedule unavailable'
                                      : reminderScheduleSummary(
                                          preferences.vaccinationSchedule,
                                        ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: enabled
                                    ? () => _editSchedule(context)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'These days and time apply to all planned vaccinations.',
                            ),
                            if (blocked || inexact) ...[
                              const SizedBox(height: AppSpacing.lg),
                              Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      AppSectionHeading(
                                        title: blocked
                                            ? 'Notifications are blocked'
                                            : 'Precise timing is off',
                                        icon: Icons.notifications_off_outlined,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        blocked
                                            ? 'Allow notifications on this device to receive reminders.'
                                            : 'Medication reminders use normal scheduling and may arrive late.',
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      FilledButton.tonal(
                                        onPressed: state.isBusy
                                            ? null
                                            : () => cubit.perform(
                                                blocked
                                                    ? NotificationAction
                                                          .notificationPermission
                                                    : NotificationAction
                                                          .exactPermission,
                                              ),
                                        child: Text(
                                          blocked
                                              ? 'Allow notifications'
                                              : 'Allow precise reminders',
                                        ),
                                      ),
                                      if (blocked)
                                        TextButton(
                                          onPressed: state.isBusy
                                              ? null
                                              : () => cubit.perform(
                                                  NotificationAction
                                                      .openSettings,
                                                ),
                                          child: const Text(
                                            'Open device settings',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (anyOn &&
                                !blocked &&
                                state.issue == null &&
                                state.plan != null) ...[
                              const SizedBox(height: AppSpacing.lg),
                              Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const AppSectionHeading(
                                        title: 'Upcoming reminders',
                                        icon: Icons.event_available_outlined,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        state.isBusy
                                            ? 'Updating reminders…'
                                            : state.plan!.reminders.isEmpty
                                            ? 'No upcoming reminders. Add a planned vaccination or a medication schedule.'
                                            : 'Next: ${MaterialLocalizations.of(context).formatShortDate(state.plan!.nextRefreshAt!)}, ${reminderTime(state.plan!.nextRefreshAt!.hour * 60 + state.plan!.nextRefreshAt!.minute)}',
                                      ),
                                      if (!state.isBusy &&
                                          state.plan!.reminders.isNotEmpty) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          '${state.plan!.reminders.length} ${state.plan!.reminders.length == 1 ? 'reminder' : 'reminders'} queued through ${MaterialLocalizations.of(context).formatShortDate(state.plan!.scheduledThrough!)}.',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                      if (!state.isBusy &&
                                          state.plan!.hasMore) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        const Text(
                                          'Open the app regularly to prepare later reminders.',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ScheduleEditor extends StatefulWidget {
  final VaccinationReminderSchedule initial;
  const _ScheduleEditor({required this.initial});
  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  final _form = GlobalKey<FormState>();
  late var _draft = widget.initial;
  bool _confirming = false;
  bool _leaving = false;

  void _save() {
    if (_leaving || _confirming) return;
    FocusScope.of(context).unfocus();
    final errors = _form.currentState!.validateGranularly();
    if (errors.isEmpty) {
      _leaving = true;
      context.pop(_draft);
      return;
    }
    final field = errors.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && field.mounted) {
        Scrollable.ensureVisible(field.context, alignment: 0.1);
      }
    });
  }

  Future<void> _cancel() async {
    if (_confirming || _leaving) return;
    if (_draft != widget.initial) {
      _confirming = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (_) => const AppConfirmationDialog(
          title: 'Discard changes?',
          message: 'Leave without updating the reminder schedule?',
          cancelLabel: 'Keep editing',
          confirmLabel: 'Discard changes',
        ),
      );
      _confirming = false;
      if (discard != true || !mounted) return;
    }
    if (mounted) {
      _leaving = true;
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<VaccinationReminderSchedule>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _cancel();
    },
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: AppFormScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Vaccination reminders',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ReminderScheduleFields(
                          initialValue: widget.initial,
                          onChanged: (value) => _draft = value,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: AppFormActions(
                  label: 'Save changes',
                  saving: false,
                  onPressed: _save,
                ),
              ),
              TextButton(onPressed: _cancel, child: const Text('Cancel')),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    ),
  );
}
