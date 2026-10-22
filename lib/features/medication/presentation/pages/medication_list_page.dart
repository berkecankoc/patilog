import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/core/widgets/error_view.dart';
import 'package:petlytics/core/widgets/my_pets_button.dart';
import 'package:petlytics/core/widgets/pet_care_title.dart';
import 'package:petlytics/features/medication/domain/entities/medication.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_state.dart';
import 'package:petlytics/features/medication/presentation/utils/medication_actions.dart';
import 'package:petlytics/features/medication/presentation/utils/medication_display.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_clock.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_doses.dart';

class MedicationListPage extends StatefulWidget {
  final String petId;
  final String? petName;
  const MedicationListPage({super.key, required this.petId, this.petName});
  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  int _tab = 0;
  GoRouter? _router;
  bool _active = false;
  bool _handledReturn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_routeChanged);
    _router = router;
    _active = router.state.uri.path == AppRoutes.medications(widget.petId);
    router.routerDelegate.addListener(_routeChanged);
  }

  void _routeChanged() {
    final active =
        _router!.state.uri.path == AppRoutes.medications(widget.petId);
    if (active && !_active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _router!.state.uri.path != AppRoutes.medications(widget.petId)) {
          return;
        }
        if (!_handledReturn) _reload();
        _handledReturn = false;
      });
    }
    _active = active;
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_routeChanged);
    super.dispose();
  }

  Future<void> _reload() =>
      context.read<MedicationCubit>().loadMedications(widget.petId);
  Future<void> _add() async {
    final saved = await context.push<bool>(
      AppRoutes.addEditMedication(widget.petId),
      extra: MedicationFormExtra(petId: widget.petId, petName: widget.petName),
    );
    if (mounted) {
      _handledReturn = true;
      if (saved == true) await _reload();
    }
  }

  Future<void> _open(Medication medication) async {
    final deleted = await context.push<String>(
      AppRoutes.medicationDetail(widget.petId, medication.id),
      extra: PetCareRouteExtra(petId: widget.petId, petName: widget.petName),
    );
    if (!mounted) return;
    _handledReturn = true;
    if (deleted != null) {
      context.read<MedicationCubit>().removeDeletedMedication(deleted);
    } else {
      await _reload();
    }
  }

  Future<void> _pickDate(DateTime date) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      await context.read<MedicationCubit>().loadDoses(picked);
    }
  }

  Widget _empty(
    String title,
    String explanation, {
    String? action,
    VoidCallback? onAction,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(explanation, textAlign: TextAlign.center),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton(onPressed: onAction, child: Text(action)),
            ),
        ],
      ),
    ),
  );

  Widget _doses(MedicationsLoaded state) {
    final cubit = context.read<MedicationCubit>();
    final busy = state.pendingAction != null;
    final date = state.doses.date;
    final doses = state.doses.doses;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous day',
                onPressed: busy || state.isRefreshing || date.year <= 2000
                    ? null
                    : () => cubit.loadDoses(
                        DateTime(date.year, date.month, date.day - 1),
                      ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  onPressed: busy || state.isRefreshing
                      ? null
                      : () => _pickDate(date),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateUtils.isSameDay(date, cubit.now())
                            ? 'Today'
                            : MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(date),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (DateUtils.isSameDay(date, cubit.now()))
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(date),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next day',
                onPressed: busy || state.isRefreshing || date.year >= 2100
                    ? null
                    : () => cubit.loadDoses(
                        DateTime(date.year, date.month, date.day + 1),
                      ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        if (!DateUtils.isSameDay(date, cubit.now()))
          TextButton(
            onPressed: busy || state.isRefreshing
                ? null
                : () => cubit.loadDoses(cubit.now()),
            child: const Text('Back to today'),
          ),
        if (state.doses.error != null)
          Flexible(
            child: AppErrorFeedback(
              message: state.doses.error!,
              retryLabel: 'Retry dose records',
              onRetry: () => cubit.loadDoses(date),
            ),
          ),
        Expanded(
          child: doses.isEmpty
              ? (state.doses.isLoading && !state.doses.hasLoaded
                    ? const Center(child: CircularProgressIndicator())
                    : _empty(
                        'No doses scheduled',
                        'There are no scheduled doses for this day.',
                        action: 'View medications',
                        onAction: () => setState(() => _tab = 1),
                      ))
              : ListView.separated(
                  key: const PageStorageKey('medication-doses'),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  itemCount: doses.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => index == 0
                      ? Text(
                          '${doses.length} doses${state.doses.hasLoaded && !state.doses.isLoading ? ' · ${doses.where((dose) => dose.log != null).length} recorded' : ''}',
                        )
                      : MedicationDoseTile(
                          key: ValueKey((
                            doses[index - 1].period.id,
                            doses[index - 1].scheduledMinute,
                          )),
                          dose: doses[index - 1],
                          known:
                              state.doses.hasLoaded && !state.doses.isLoading,
                          loading: state.doses.isLoading,
                          busy: busy || state.isRefreshing,
                        ),
                ),
        ),
      ],
    );
  }

  Widget _catalog(MedicationsLoaded state) {
    final groups = [
      for (final status in MedicationStatus.values)
        (
          status,
          state.medications
              .where(
                (medication) =>
                    medication.statusOn(state.currentTime) == status,
              )
              .toList(),
        ),
    ];
    return ListView(
      key: const PageStorageKey('medication-catalog'),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 128),
      children: [
        for (final (status, medications) in groups)
          if (medications.isNotEmpty) ...[
            AppSectionHeading(
              title: switch (status) {
                MedicationStatus.active => 'Active',
                MedicationStatus.upcoming => 'Upcoming',
                MedicationStatus.completed => 'History',
              },
              icon: switch (status) {
                MedicationStatus.active => Icons.medication_outlined,
                MedicationStatus.upcoming => Icons.event_outlined,
                MedicationStatus.completed => Icons.history_outlined,
              },
            ),
            const SizedBox(height: 12),
            for (final medication in medications) ...[
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  onTap: state.pendingAction != null || state.isRefreshing
                      ? null
                      : () => _open(medication),
                  title: Text(
                    medication.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    status == MedicationStatus.active
                        ? medicationSchedule(
                            medication.periodOn(state.currentTime)!,
                          )
                        : status == MedicationStatus.upcoming
                        ? 'Starts ${MaterialLocalizations.of(context).formatShortDate(medication.pendingPeriod(state.currentTime)!.startDate)}'
                        : 'Ended ${MaterialLocalizations.of(context).formatShortDate(medication.effectiveEnd(medication.periods.last)!)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => MedicationClock(
    onResume: _reload,
    child: BlocBuilder<MedicationCubit, MedicationState>(
      builder: (context, state) {
        final loaded = state is MedicationsLoaded ? state : null;
        final busy = loaded?.pendingAction != null;
        return PopScope(
          canPop: !busy,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              toolbarHeight: PetCareTitle.toolbarHeight(context),
              title: PetCareTitle(
                title: 'Medications',
                petName: widget.petName,
              ),
              leading: busy
                  ? const IconButton(onPressed: null, icon: BackButtonIcon())
                  : null,
              actions: [MyPetsButton(enabled: !busy)],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child:
                    loaded?.isRefreshing == true ||
                        loaded?.doses.isLoading == true ||
                        busy
                    ? const LinearProgressIndicator(
                        semanticsLabel: 'Updating medications',
                      )
                    : const SizedBox(height: 4),
              ),
            ),
            floatingActionButton:
                loaded != null && (_tab == 1 || loaded.medications.isEmpty)
                ? FloatingActionButton.extended(
                    isExtended:
                        MediaQuery.textScalerOf(context).scale(14) <= 21,
                    onPressed: busy || loaded.isRefreshing ? null : _add,
                    icon: const Icon(Icons.add),
                    tooltip: 'Add medication',
                    label: const Text('Add medication'),
                  )
                : null,
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
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                              child: SizedBox(
                                width: double.infinity,
                                child:
                                    MediaQuery.textScalerOf(context).scale(14) >
                                        21
                                    ? Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          for (final (index, title) in [
                                            'Doses',
                                            'Medications',
                                          ].indexed)
                                            ChoiceChip(
                                              label: Text(title),
                                              selected: _tab == index,
                                              showCheckmark: false,
                                              onSelected: busy
                                                  ? null
                                                  : (_) => setState(
                                                      () => _tab = index,
                                                    ),
                                            ),
                                        ],
                                      )
                                    : SegmentedButton<int>(
                                        segments: const [
                                          ButtonSegment(
                                            value: 0,
                                            label: Text('Doses'),
                                          ),
                                          ButtonSegment(
                                            value: 1,
                                            label: Text('Medications'),
                                          ),
                                        ],
                                        selected: {_tab},
                                        showSelectedIcon: false,
                                        onSelectionChanged: busy
                                            ? null
                                            : (value) => setState(
                                                () => _tab = value.single,
                                              ),
                                      ),
                              ),
                            ),
                            Expanded(
                              child: loaded.medications.isEmpty
                                  ? _empty(
                                      'No medications yet',
                                      'Add a medication and its schedule to start dose tracking.',
                                    )
                                  : _tab == 0
                                  ? _doses(loaded)
                                  : _catalog(loaded),
                            ),
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
