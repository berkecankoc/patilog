import 'package:patilog/core/error/failure.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:patilog/core/theme/app_spacing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/widgets/app_related_records_section.dart';
import 'package:patilog/core/widgets/app_related_clinical_details.dart';
import 'package:patilog/core/widgets/app_error_feedback.dart';
import 'package:patilog/features/medication/domain/entities/medication.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_state.dart';
import 'package:patilog/features/medication/presentation/utils/medication_display.dart';

class VisitMedicationsSection extends StatelessWidget {
  final String petId;
  final String visitId;
  final String? parentClinicName;
  final String? parentVeterinarianName;
  final ValueChanged<Medication>? onOpen;
  const VisitMedicationsSection({
    super.key,
    required this.petId,
    required this.visitId,
    this.parentClinicName,
    this.parentVeterinarianName,
    this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    void load() => context.read<MedicationCubit>().loadMedications(
      petId,
      vetVisitId: visitId,
    );
    return AppRelatedRecordsSection(
      key: ValueKey(('visit-medications', petId, visitId)),
      title: AppLocalizations.of(context).linkedMedications,
      icon: Icons.medication_outlined,
      onLoad: load,
      child: BlocBuilder<MedicationCubit, MedicationState>(
        builder: (context, state) => switch (state) {
          MedicationsLoaded(:final medications, :final refreshError) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (refreshError != null)
                AppErrorFeedback(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  message: AppLocalizations.of(context).medicationsLoadFailed,
                  retryLabel: AppLocalizations.of(context).retryMedications,
                  onRetry: load,
                ),
              if (medications.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(AppLocalizations.of(context).noLinkedMedications),
                ),
              if (medications.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: ListView.separated(
                    key: PageStorageKey(('visit-medications', petId, visitId)),
                    primary: false,
                    shrinkWrap: true,
                    itemCount: medications.length,
                    separatorBuilder: (_, _) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final medication = medications[index];
                      return AppRelatedRecordTile(
                        title: medication.name,
                        icon: Icons.medication_outlined,
                        openLabel: AppLocalizations.of(
                          context,
                        ).openMedication(medication.name),
                        onOpen: onOpen == null
                            ? null
                            : () => onOpen!(medication),
                        details: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final period in medication.periods.where(
                              (period) => period.vetVisitId == visitId,
                            )) ...[
                              const SizedBox(height: 8),
                              Text(
                                medicationDateRange(
                                  context,
                                  medication,
                                  period,
                                ),
                              ),
                              Text(
                                medicationSchedule(
                                  AppLocalizations.of(context),
                                  period,
                                ),
                              ),
                              AppRelatedClinicalDetails(
                                clinicName: period.clinicName,
                                veterinarianName: period.veterinarianName,
                                parentClinicName: parentClinicName,
                                parentVeterinarianName: parentVeterinarianName,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          MedicationError(:final failure) => AppErrorFeedback(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            message: failure is NotFoundFailure
                ? AppLocalizations.of(context).medicationNotFound
                : AppLocalizations.of(context).medicationsLoadFailed,
            retryLabel: AppLocalizations.of(context).retryMedications,
            onRetry: load,
          ),
          _ => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ),
    );
  }
}
