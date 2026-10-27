import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_related_records_section.dart';
import 'package:petlytics/core/widgets/app_related_clinical_details.dart';
import 'package:petlytics/features/vaccination/domain/entities/vaccination.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_state.dart';

class VisitVaccinationsSection extends StatelessWidget {
  final String petId;
  final String visitId;
  final String? parentClinicName;
  final String? parentVeterinarianName;
  final ValueChanged<Vaccination>? onOpen;

  const VisitVaccinationsSection({
    super.key,
    required this.petId,
    required this.visitId,
    this.parentClinicName,
    this.parentVeterinarianName,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    void load() => context.read<VaccinationCubit>().loadVaccinations(
      petId,
      vetVisitId: visitId,
    );
    return AppRelatedRecordsSection(
      key: ValueKey((petId, visitId)),
      title: 'Linked vaccinations',
      icon: Icons.vaccines_outlined,
      onLoad: load,
      child: BlocBuilder<VaccinationCubit, VaccinationState>(
        builder: (context, state) => switch (state) {
          VaccinationsLoaded(:final vaccinations, :final refreshError) =>
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (refreshError != null)
                  AppErrorFeedback(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    message: refreshError,
                    retryLabel: 'Retry vaccinations',
                    onRetry: load,
                  ),
                if (vaccinations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text('No vaccinations linked to this visit.'),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                    ),
                    child: ListView.separated(
                      key: PageStorageKey((
                        'visit-vaccinations',
                        petId,
                        visitId,
                      )),
                      primary: false,
                      shrinkWrap: true,
                      itemCount: vaccinations.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final vaccination = vaccinations[index];
                        return AppRelatedRecordTile(
                          title: vaccination.vaccineName,
                          icon: Icons.vaccines_outlined,
                          openLabel:
                              'Open vaccination: ${vaccination.vaccineName}',
                          onOpen: onOpen == null
                              ? null
                              : () => onOpen!(vaccination),
                          details: AppRelatedClinicalDetails(
                            clinicName: vaccination.clinicName,
                            veterinarianName: vaccination.veterinarianName,
                            parentClinicName: parentClinicName,
                            parentVeterinarianName: parentVeterinarianName,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          VaccinationError(:final message) => AppErrorFeedback(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            message: message,
            retryLabel: 'Retry vaccinations',
            onRetry: load,
          ),
          _ => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading linked vaccinations',
              ),
            ),
          ),
        },
      ),
    );
  }
}
