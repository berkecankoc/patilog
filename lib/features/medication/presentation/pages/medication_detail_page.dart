import 'package:patilog/core/error/failure.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:patilog/core/router/pet_care_changes.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:flutter/material.dart';
import 'package:patilog/core/theme/app_spacing.dart';
import 'package:patilog/core/widgets/pet_care_tabs.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/core/router/pet_care_route_extra.dart';
import 'package:patilog/core/widgets/app_detail_field.dart';
import 'package:patilog/core/widgets/app_error_feedback.dart';
import 'package:patilog/core/widgets/app_related_records_section.dart';
import 'package:patilog/core/widgets/app_related_clinical_details.dart';
import 'package:patilog/core/widgets/app_section_heading.dart';
import 'package:patilog/core/widgets/error_view.dart';
import 'package:patilog/core/widgets/my_pets_button.dart';
import 'package:patilog/core/widgets/pet_care_title.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_period.dart';
import 'package:patilog/features/medication/domain/utils/medication_calendar.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_state.dart';
import 'package:patilog/features/medication/presentation/utils/medication_actions.dart';
import 'package:patilog/features/medication/presentation/utils/medication_display.dart';
import 'package:patilog/features/medication/presentation/widgets/medication_clock.dart';
import 'package:patilog/features/medication/presentation/widgets/medication_dose_calendar.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_visits_cubit.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_state.dart';

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
        AppDetailField(
          label: AppLocalizations.of(context).clinic,
          value: period.clinicName,
        ),
      if (period.veterinarianName != null)
        AppDetailField(
          label: AppLocalizations.of(context).veterinarian,
          value: period.veterinarianName,
        ),
      if (period.notes != null)
        AppDetailField(
          label: AppLocalizations.of(context).notes,
          value: period.notes,
        ),
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
      title: AppLocalizations.of(context).linkedVetVisit,
      icon: Icons.link_outlined,
      onLoad: () => context.read<MedicationVisitsCubit>().loadVisit(
        widget.petId,
        visitId,
      ),
      child: BlocBuilder<MedicationVisitsCubit, Map<String, VetVisitState>>(
        builder: (context, visits) => switch (visits[visitId]) {
          VetVisitLoaded(:final visit, :final refreshError) =>
            visit.id != visitId
                ? Text(AppLocalizations.of(context).reopenVisitSection)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (refreshError != null)
                        AppErrorFeedback(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          message: AppLocalizations.of(context).visitLoadFailed,
                          retryLabel: AppLocalizations.of(context).retryVisit,
                          onRetry: () => context
                              .read<MedicationVisitsCubit>()
                              .loadVisit(widget.petId, visitId),
                        ),
                      AppRelatedRecordTile(
                        title: visit.reason,
                        icon: Icons.event_note_outlined,
                        openLabel: AppLocalizations.of(context).openVetVisit,
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
          VetVisitError(:final failure) => AppErrorFeedback(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            message: failure is NotFoundFailure
                ? AppLocalizations.of(context).visitNotFound
                : AppLocalizations.of(context).visitLoadFailed,
            retryLabel: AppLocalizations.of(context).retryVisit,
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
        medicationSchedule(AppLocalizations.of(context), period),
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
          AppLocalizations.of(context).scheduleChangeSummary(
            dates.formatShortDate(period.startDate),
            medicationSchedule(AppLocalizations.of(context), period),
          ),
        ),
        children: [
          if (period.dosageInstructions != null) ...[
            AppDetailField(
              label: AppLocalizations.of(context).dosageInstructions,
              value: period.dosageInstructions,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            end == null
                ? AppLocalizations.of(context).noEndDate
                : DateUtils.isSameDay(period.startDate, end)
                ? AppLocalizations.of(context).oneDay
                : AppLocalizations.of(
                    context,
                  ).untilDate(dates.formatShortDate(end)),
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
                child: Text(AppLocalizations.of(context).editChange),
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
                  child: Text(AppLocalizations.of(context).cancelChange),
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
          AppSectionHeading(
            title: AppLocalizations.of(context).schedule,
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
            child: Text(AppLocalizations.of(context).editDetails),
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
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      medication.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(switch (medication.statusOn(state.currentTime)) {
                      MedicationStatus.active => AppLocalizations.of(
                        context,
                      ).active,
                      MedicationStatus.upcoming => AppLocalizations.of(
                        context,
                      ).upcoming,
                      MedicationStatus.completed => AppLocalizations.of(
                        context,
                      ).completed,
                    }),
                    const SizedBox(height: 24),
                    if (current != null || pending.isNotEmpty) ...[
                      _schedule(medication, current, pending, busy),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _edit(medication),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(AppLocalizations.of(context).editMedication),
                    ),
                    if (current == null && pending.isEmpty) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _edit(medication, newSchedule: true),
                        icon: const Icon(Icons.event_repeat_outlined),
                        label: Text(AppLocalizations.of(context).scheduleAgain),
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
                            key: PageStorageKey((
                              'medication-clinical',
                              current.id,
                            )),
                            shape: const Border(),
                            collapsedShape: const Border(),
                            leading: const Icon(
                              Icons.local_hospital_outlined,
                              size: 20,
                            ),
                            title: Semantics(
                              header: true,
                              child: Text(
                                AppLocalizations.of(context).clinicAndNotes,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
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
                      key: _calendarKey,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      onPressed: busy ? null : () => _toggleCalendar(state),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        _showCalendar
                            ? AppLocalizations.of(context).hideDoseCalendar
                            : AppLocalizations.of(context).doseCalendar,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showCalendar && state.calendar != null)
                SliverPadding(
                  padding: const EdgeInsets.only(top: 12),
                  sliver: MedicationDoseCalendar(state: state),
                ),
              if (history.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(top: 16),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ExpansionTile(
                        key: PageStorageKey((
                          'medication-history',
                          medication.id,
                        )),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        maintainState: true,
                        title: AppSectionHeading(
                          title: AppLocalizations.of(context).previousSchedules,
                          icon: Icons.history_outlined,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          for (final period in history)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _previousSchedule(
                                medication,
                                period,
                                busy,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
              title: PetCareTitle(
                title: AppLocalizations.of(context).medication,
                petName: widget.petName,
              ),
              leading: careBackButton(context, busy: busy),
              actions: [
                MyPetsButton(enabled: !busy),
                if (loaded != null)
                  IconButton(
                    tooltip: AppLocalizations.of(context).deleteMedication,
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
                                message: state.failure is NotFoundFailure
                                    ? AppLocalizations.of(
                                        context,
                                      ).medicationNotFound
                                    : AppLocalizations.of(
                                        context,
                                      ).medicationsLoadFailed,
                                onRetry: _reload,
                              )
                            : const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            if (loaded.actionError != null ||
                                loaded.refreshError != null)
                              Flexible(
                                child: AppErrorFeedback(
                                  message: loaded.actionError != null
                                      ? medicationActionError(
                                          AppLocalizations.of(context),
                                          loaded.failedAction,
                                        )
                                      : AppLocalizations.of(
                                          context,
                                        ).medicationsLoadFailed,
                                  retryLabel: loaded.failedAction != null
                                      ? AppLocalizations.of(context).retryAction
                                      : AppLocalizations.of(context).retry,
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
