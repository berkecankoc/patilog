import 'package:flutter/material.dart';
import 'package:patilog/core/widgets/app_section_heading.dart';
import 'package:patilog/core/widgets/care_record_card.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/domain/entities/medication_dose.dart';
import 'package:patilog/features/medication/presentation/utils/medication_display.dart';
import 'package:patilog/features/medication/presentation/widgets/medication_doses.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

/// Presentation only: each navigation root retains its own queries and writes.
class MedicationDoseListContent extends StatelessWidget {
  final List<MedicationDose> doses;
  final bool known;
  final bool loading;
  final bool busy;
  final Widget empty;
  final Widget? header;
  final Map<String, Pet>? petsById;
  final MedicationDoseEditor Function(MedicationDose)? editorFor;
  final ValueChanged<MedicationDose>? onRecord;

  const MedicationDoseListContent({
    super.key,
    required this.doses,
    required this.known,
    required this.loading,
    required this.busy,
    required this.empty,
    this.header,
    this.petsById,
    this.editorFor,
    this.onRecord,
  });

  Widget _item(MedicationDose dose) => MedicationDoseTile(
    key: petsById == null
        ? ValueKey((dose.period.id, dose.scheduledMinute))
        : ValueKey((dose.period.id, dose.scheduledDate, dose.scheduledMinute)),
    dose: dose,
    known: known,
    loading: loading,
    busy:
        busy ||
        petsById != null && !petsById!.containsKey(dose.medication.petId),
    petIdentity: petsById == null
        ? null
        : CarePetIdentity(pet: petsById![dose.medication.petId]),
    editor: editorFor?.call(dose),
    onRecord: onRecord == null ? null : () => onRecord!(dose),
  );

  @override
  Widget build(BuildContext context) {
    if (petsById == null) {
      final strings = AppLocalizations.of(context);
      return doses.isEmpty
          ? empty
          : ListView.separated(
              key: const PageStorageKey('medication-doses'),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              itemCount: doses.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) => index == 0
                  ? Text(
                      known
                          ? strings.doseCountRecorded(
                              doses.length,
                              doses.where((dose) => dose.log != null).length,
                            )
                          : strings.doseCount(doses.length),
                    )
                  : _item(doses[index - 1]),
            );
    }
    return CustomScrollView(
      key: const PageStorageKey('global-doses'),
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        if (doses.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: empty)
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 112),
            sliver: SliverList.separated(
              itemCount: doses.length,
              itemBuilder: (_, index) => _item(doses[index]),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
            ),
          ),
      ],
    );
  }
}

class MedicationDateSelector extends StatelessWidget {
  final DateTime date;
  final DateTime Function() now;
  final ValueChanged<DateTime>? onChanged;
  final bool compact;

  const MedicationDateSelector({
    super.key,
    required this.date,
    required this.now,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final today = DateUtils.isSameDay(date, now());
    final formatted = MaterialLocalizations.of(context).formatMediumDate(date);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              IconButton(
                tooltip: strings.previousDay,
                onPressed: onChanged == null || date.year <= 2000
                    ? null
                    : () => onChanged!(
                        DateTime(date.year, date.month, date.day - 1),
                      ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onChanged == null
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null && context.mounted) {
                            onChanged!(picked);
                          }
                        },
                  child: compact
                      ? Text(
                          today ? strings.todayWithDate(formatted) : formatted,
                          textAlign: TextAlign.center,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              today ? strings.today : formatted,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (today) Text(formatted),
                          ],
                        ),
                ),
              ),
              IconButton(
                tooltip: strings.nextDay,
                onPressed: onChanged == null || date.year >= 2100
                    ? null
                    : () => onChanged!(
                        DateTime(date.year, date.month, date.day + 1),
                      ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        if (!today)
          TextButton(
            onPressed: onChanged == null ? null : () => onChanged!(now()),
            child: Text(strings.backToToday),
          ),
      ],
    );
  }
}

class MedicationCatalogContent extends StatelessWidget {
  final List<Medication> medications;
  final DateTime currentTime;
  final ValueChanged<Medication>? onOpen;
  final Map<String, Pet>? petsById;
  final Widget? header;

  const MedicationCatalogContent({
    super.key,
    required this.medications,
    required this.currentTime,
    required this.onOpen,
    this.petsById,
    this.header,
  });

  Widget _item(
    BuildContext context,
    Medication medication,
    MedicationStatus status,
  ) {
    final strings = AppLocalizations.of(context);
    final open =
        onOpen == null ||
            petsById != null && !petsById!.containsKey(medication.petId)
        ? null
        : () => onOpen!(medication);
    if (petsById != null) {
      final period =
          medication.periodOn(currentTime) ??
          medication.pendingPeriod(currentTime) ??
          medication.periods.last;
      return CareRecordCard(
        key: ValueKey(medication.id),
        pet: petsById![medication.petId],
        title: medication.name,
        icon: Icons.medication_outlined,
        details: Text(medicationSchedule(strings, period)),
        onOpen: open,
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: open,
        title: Text(
          medication.name,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          status == MedicationStatus.active
              ? medicationSchedule(strings, medication.periodOn(currentTime)!)
              : status == MedicationStatus.upcoming
              ? strings.startsOn(
                  MaterialLocalizations.of(context).formatShortDate(
                    medication.pendingPeriod(currentTime)!.startDate,
                  ),
                )
              : strings.endedOn(
                  MaterialLocalizations.of(context).formatShortDate(
                    medication.effectiveEnd(medication.periods.last)!,
                  ),
                ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final global = petsById != null;
    final groups = [
      for (final status in MedicationStatus.values)
        (
          status,
          medications.where((m) => m.statusOn(currentTime) == status).toList(),
        ),
    ];
    Widget heading(MedicationStatus status) => AppSectionHeading(
      title: switch (status) {
        MedicationStatus.active => strings.active,
        MedicationStatus.upcoming => strings.upcoming,
        MedicationStatus.completed => strings.history,
      },
      icon: status == MedicationStatus.active
          ? Icons.medication_outlined
          : global
          ? Icons.history
          : status == MedicationStatus.upcoming
          ? Icons.event_outlined
          : Icons.history_outlined,
    );
    if (!global) {
      return ListView(
        key: const PageStorageKey('medication-catalog'),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 128),
        children: [
          for (final (status, rows) in groups)
            if (rows.isNotEmpty) ...[
              heading(status),
              const SizedBox(height: 12),
              for (final medication in rows) ...[
                _item(context, medication, status),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
            ],
        ],
      );
    }
    return CustomScrollView(
      key: const PageStorageKey('global-medications'),
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        if (medications.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: CareEmptyView(
              icon: Icons.medication_outlined,
              title: strings.noMedications,
              message: strings.medicationsEmpty,
            ),
          ),
        for (final (status, rows) in groups)
          if (rows.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              sliver: SliverToBoxAdapter(child: heading(status)),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (_, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _item(context, rows[index], status),
                ),
              ),
            ),
          ],
        const SliverToBoxAdapter(child: SizedBox(height: 112)),
      ],
    );
  }
}
