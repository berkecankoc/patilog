import 'package:petlytics/core/router/pet_care_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:flutter/material.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/pet_care_tabs.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/widgets/app_detail_field.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_related_records_section.dart';
import 'package:petlytics/core/widgets/app_related_clinical_details.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/core/widgets/my_pets_button.dart';
import 'package:petlytics/core/widgets/pet_care_title.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/domain/entities/medication_period.dart';
import 'package:petlytics/features/medication/domain/utils/medication_calendar.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_state.dart';
import 'package:petlytics/features/medication/presentation/utils/medication_actions.dart';
import 'package:petlytics/features/medication/presentation/utils/medication_display.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_clock.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_dose_calendar.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_visits_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';

class MedicationDetailPage extends StatefulWidget {
  final String petId;
  final String medicationId;
  final String? petName;
  final DateTime? initialDoseDate;
  const MedicationDetailPage({
    super.key,
    required this.petId,
    required this.medicationId,
    this.petName,
    this.initialDoseDate,
  });
  @override
  State<MedicationDetailPage> createState() => _MedicationDetailPageState();
}

class _MedicationDetailPageState extends State<MedicationDetailPage> {
  final _scroll = ScrollController();
  final _calendarKey = GlobalKey();
  bool _showCalendar = false;
  bool _openedInitialCalendar = false;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() => context.read<MedicationCubit>().loadMedication(
    widget.petId,
    widget.medicationId,
  );
  Future<void> _edit(
    Medication medication, {
    String? periodId,
    bool newSchedule = false,
  }) async {
    final saved = await context.push<bool>(
      AppRoutes.addEditMedication(widget.petId),
      extra: MedicationFormExtra(
        petId: widget.petId,
        petName: widget.petName,
        medication: medication,
        periodId: periodId,
        newSchedule: newSchedule,
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _openVisit(String visitId) async {
    await context.push(
      AppRoutes.vetVisitDetail(widget.petId, visitId),
      extra: PetCareRouteExtra(petId: widget.petId, petName: widget.petName),
    );
    if (!mounted) return;
    await _reload();
    if (!mounted) return;
    final state = context.read<MedicationCubit>().state;
    if (state is MedicationsLoaded &&
        state.medications.any(
          (medication) =>
              medication.periods.any((period) => period.vetVisitId == visitId),
        )) {
      await context.read<MedicationVisitsCubit>().loadVisit(
        widget.petId,
        visitId,
      );
    }
  }

  Widget _clinical(MedicationPeriod period) {
    final fields = [
      if (period.clinicName != null)
        AppDetailField(label: 'Clinic', value: period.clinicName),
      if (period.veterinarianName != null)
        AppDetailField(label: 'Veterinarian', value: period.veterinarianName),
      if (period.notes != null)
        AppDetailField(label: 'Notes', value: period.notes),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < fields.length; index++) ...[
          if (index > 0) const SizedBox(height: 16),
          fields[index],
        ],
      ],
    );
  }

  Future<void> _toggleCalendar(MedicationsLoaded state) async {
    setState(() => _showCalendar = !_showCalendar);
    if (!_showCalendar || state.calendar != null) return;
    final medication = state.medications.single;
    final initial = switch (medication.statusOn(state.currentTime)) {
      MedicationStatus.active => state.currentTime,
      MedicationStatus.upcoming =>
        medication.pendingPeriod(state.currentTime)!.startDate,
      MedicationStatus.completed => medication.effectiveEnd(
        medication.periods.last,
      )!,
    };
    final cubit = context.read<MedicationCubit>();
    await cubit.loadCalendar(initial);
    if (mounted) cubit.selectCalendarDay(initial);
  }

  Widget _visit(MedicationPeriod period, bool busy) {
    final visitId = period.vetVisitId!;
    return AppRelatedRecordsSection(
      key: ValueKey(('medication-visit', period.id, visitId)),
      title: 'Linked vet visit',
      icon: Icons.link_outlined,
      onLoad: () => context.read<MedicationVisitsCubit>().loadVisit(
        widget.petId,
        visitId,
      ),
      child: BlocBuilder<MedicationVisitsCubit, Map<String, VetVisitState>>(
        builder: (context, visits) => switch (visits[visitId]) {
          VetVisitLoaded(:final visit, :final refreshError) =>
            visit.id != visitId
                ? const Text('Open this section again to refresh the visit.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (refreshError != null)
                        AppErrorFeedback(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          message: refreshError,
                          retryLabel: 'Retry visit',
                          onRetry: () => context
                              .read<MedicationVisitsCubit>()
                              .loadVisit(widget.petId, visitId),
                        ),
                      AppRelatedRecordTile(
                        title: visit.reason,
                        icon: Icons.event_note_outlined,
                        openLabel: 'Open vet visit',
                        onOpen: busy ? null : () => _openVisit(visitId),
                        details: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!DateUtils.isSameDay(
                              period.startDate,
                              visit.visitedOn,
                            ))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  MaterialLocalizations.of(
                                    context,
                                  ).formatShortDate(visit.visitedOn),
                                ),
                              ),
                            AppRelatedClinicalDetails(
                              clinicName: visit.clinicName,
                              veterinarianName: visit.veterinarianName,
                              parentClinicName: period.clinicName,
                              parentVeterinarianName: period.veterinarianName,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          VetVisitError(:final message) => AppErrorFeedback(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            message: message,
            retryLabel: 'Retry visit',
            onRetry: () => context.read<MedicationVisitsCubit>().loadVisit(
              widget.petId,
              visitId,
            ),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ),
    );
  }

  Widget _usage(MedicationPeriod period) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        medicationSchedule(period),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      if (period.dosageInstructions != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(period.dosageInstructions!),
        ),
    ],
  );

  Widget _pendingChange(
    Medication medication,
    MedicationPeriod period,
    bool busy,
  ) {
    final dates = MaterialLocalizations.of(context);
    final end = medication.effectiveEnd(period);
    return ListTileTheme.merge(
      minLeadingWidth: 20,
      horizontalTitleGap: 8,
      titleAlignment: ListTileTitleAlignment.center,
      child: ExpansionTile(
        key: PageStorageKey(('medication-change', medication.id, period.id)),
        maintainState: true,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        leading: const Icon(Icons.subdirectory_arrow_right, size: 20),
        title: Text(
          'From ${dates.formatShortDate(period.startDate)}: ${medicationSchedule(period)}',
        ),
        children: [
          if (period.dosageInstructions != null) ...[
            AppDetailField(
              label: 'Dosage instructions',
              value: period.dosageInstructions,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            end == null
                ? 'No end date'
                : DateUtils.isSameDay(period.startDate, end)
                ? 'One day'
                : 'Until ${dates.formatShortDate(end)}',
          ),
          if (period.clinicName != null ||
              period.veterinarianName != null ||
              period.notes != null) ...[
            const SizedBox(height: 16),
            _clinical(period),
          ],
          if (period.vetVisitId != null) ...[
            const SizedBox(height: 16),
            _visit(period, busy),
          ],
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => _edit(medication, periodId: period.id),
                child: const Text('Edit change'),
              ),
              if (medication.periods.indexOf(period) > 0)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => performMedicationAction(
                          context,
                          context.read<MedicationCubit>(),
                          DeleteMedicationPeriodAction(
                            medication.id,
                            period.id,
                          ),
                        ),
                  child: const Text('Cancel change'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _schedule(
    Medication medication,
    MedicationPeriod? current,
    List<MedicationPeriod> pending,
    bool busy,
  ) => Card(
    key: ValueKey(('medication-schedule', medication.id)),
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeading(
            title: 'Schedule',
            icon: Icons.schedule_outlined,
          ),
          const SizedBox(height: 16),
          if (current != null) ...[
            _usage(current),
            const SizedBox(height: 12),
            Text(medicationDateRange(context, medication, current)),
          ],
          for (final period in pending) ...[
            if (current != null || period != pending.first)
              const Divider(height: 24),
            _pendingChange(medication, period, busy),
          ],
        ],
      ),
    ),
  );

  Widget _previousSchedule(
    Medication medication,
    MedicationPeriod period,
    bool busy,
  ) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeading(
            title: medicationDateRange(context, medication, period),
            icon: Icons.history_outlined,
          ),
          const SizedBox(height: 16),
          _usage(period),
          TextButton(
            onPressed: busy
                ? null
                : () => _edit(medication, periodId: period.id),
            child: const Text('Edit details'),
          ),
          const SizedBox(height: 8),
          _clinical(period),
          if (period.vetVisitId != null) ...[
            const SizedBox(height: 16),
            _visit(period, busy),
          ],
        ],
      ),
    ),
  );

  Widget _content(MedicationsLoaded state) {
    final medication = state.medications.single;
    final busy = state.pendingAction != null || state.isRefreshing;
    final current = medication.periodOn(state.currentTime);
    final pending = medication.periods
        .where(
          (period) =>
              calendarDayNumber(period.startDate) >
              calendarDayNumber(state.currentTime),
        )
        .toList();
    final history = medication.periods
        .where((period) => period != current && !pending.contains(period))
        .toList()
        .reversed;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          medication.name,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(switch (medication.statusOn(state.currentTime)) {
          MedicationStatus.active => 'Active',
          MedicationStatus.upcoming => 'Upcoming',
          MedicationStatus.completed => 'Completed',
        }),
        const SizedBox(height: 24),
        if (current != null || pending.isNotEmpty) ...[
          _schedule(medication, current, pending, busy),
          const SizedBox(height: 16),
        ],
        OutlinedButton.icon(
          onPressed: busy ? null : () => _edit(medication),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit medication'),
        ),
        if (current == null && pending.isEmpty) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: busy ? null : () => _edit(medication, newSchedule: true),
            icon: const Icon(Icons.event_repeat_outlined),
            label: const Text('Schedule doses again'),
          ),
        ],
        if (current != null &&
            (current.clinicName != null ||
                current.veterinarianName != null ||
                current.notes != null)) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: ListTileTheme.merge(
              minLeadingWidth: 20,
              horizontalTitleGap: 8,
              child: ExpansionTile(
                key: PageStorageKey(('medication-clinical', current.id)),
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const Icon(Icons.local_hospital_outlined, size: 20),
                title: Semantics(
                  header: true,
                  child: Text(
                    'Clinic & notes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [_clinical(current)],
              ),
            ),
          ),
        ],
        if (current?.vetVisitId != null) ...[
          const SizedBox(height: 16),
          _visit(current!, busy),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          onPressed: busy ? null : () => _toggleCalendar(state),
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(_showCalendar ? 'Hide dose calendar' : 'Dose calendar'),
        ),
        if (_showCalendar && state.calendar != null) ...[
          const SizedBox(height: 12),
          Card(
            key: _calendarKey,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: MedicationDoseCalendar(state: state),
            ),
          ),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              key: PageStorageKey(('medication-history', medication.id)),
              shape: const Border(),
              collapsedShape: const Border(),
              maintainState: true,
              title: const AppSectionHeading(
                title: 'Previous schedules',
                icon: Icons.history_outlined,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final period in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _previousSchedule(medication, period, busy),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => MedicationClock(
    onResume: _reload,
    child: BlocConsumer<MedicationCubit, MedicationState>(
      listenWhen: (previous, current) =>
          current is MedicationDeleted ||
          previous is MedicationsLoaded &&
              previous.pendingAction != null &&
              current is MedicationsLoaded &&
              current.pendingAction == null &&
              current.actionError == null,
      listener: (context, state) {
        if (state case MedicationDeleted(:final medicationId)) {
          PetCareChanges.recordChanged(
            context,
            widget.petId,
            PetCareTab.medications,
            deletedId: medicationId,
          );
          context.pop(medicationId);
        } else {
          // Successful dose/period actions must update the cached tracking tab.
          PetCareChanges.recordChanged(
            context,
            widget.petId,
            PetCareTab.medications,
          );
        }
      },
      builder: (context, state) {
        if (!_openedInitialCalendar &&
            widget.initialDoseDate != null &&
            state is MedicationsLoaded) {
          _openedInitialCalendar = true;
          _showCalendar = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final cubit = context.read<MedicationCubit>();
            await cubit.loadCalendar(widget.initialDoseDate!);
            if (!mounted) return;
            cubit.selectCalendarDay(widget.initialDoseDate!);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final target = _calendarKey.currentContext;
              if (mounted && target != null) {
                Scrollable.ensureVisible(target, alignment: 0.05);
              }
            });
          });
        }
        final loaded = state is MedicationsLoaded ? state : null;
        final busy = loaded?.pendingAction != null;
        return PopScope<String>(
          canPop: !busy,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              toolbarHeight: PetCareTitle.toolbarHeight(context),
              title: PetCareTitle(title: 'Medication', petName: widget.petName),
              leading: careBackButton(context, busy: busy),
              actions: [
                MyPetsButton(enabled: !busy),
                if (loaded != null)
                  IconButton(
                    tooltip: 'Delete medication',
                    onPressed:
                        busy || loaded.isRefreshing || loaded.doses.isLoading
                        ? null
                        : () => performMedicationAction(
                            context,
                            context.read<MedicationCubit>(),
                            DeleteMedicationAction(widget.medicationId),
                          ),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: busy || loaded?.isRefreshing == true
                    ? const LinearProgressIndicator()
                    : const SizedBox(height: 4),
              ),
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: loaded == null
                      ? state is MedicationError
                            ? ErrorView(
                                message: state.message,
                                onRetry: _reload,
                              )
                            : const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            if (loaded.actionError != null ||
                                loaded.refreshError != null)
                              Flexible(
                                child: AppErrorFeedback(
                                  message:
                                      loaded.actionError ??
                                      loaded.refreshError!,
                                  retryLabel: loaded.failedAction != null
                                      ? 'Retry action'
                                      : 'Retry',
                                  onRetry: () {
                                    final action = loaded.failedAction;
                                    if (action != null) {
                                      performMedicationAction(
                                        context,
                                        context.read<MedicationCubit>(),
                                        action,
                                      );
                                    } else {
                                      _reload();
                                    }
                                  },
                                ),
                              ),
                            Expanded(child: _content(loaded)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
