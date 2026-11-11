import 'package:patilog/core/error/failure.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/theme/app_spacing.dart';
import 'package:patilog/core/widgets/app_error_feedback.dart';
import 'package:patilog/core/widgets/app_related_records_section.dart';
import 'package:patilog/core/widgets/app_related_clinical_details.dart';
import 'package:patilog/features/vaccination/domain/entities/vaccination.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_state.dart';

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
      title: AppLocalizations.of(context).linkedVaccinations,
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
                    message: AppLocalizations.of(
                      context,
                    ).vaccinationsLoadFailed,
                    retryLabel: AppLocalizations.of(context).retryVaccinations,
                    onRetry: load,
                  ),
                if (vaccinations.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(
                      AppLocalizations.of(context).noLinkedVaccinations,
                    ),
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
                          openLabel: AppLocalizations.of(
                            context,
                          ).openVaccination(vaccination.vaccineName),
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
          VaccinationError(:final failure) => AppErrorFeedback(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            message: failure is NotFoundFailure
                ? AppLocalizations.of(context).vaccinationNotFound
                : AppLocalizations.of(context).vaccinationsLoadFailed,
            retryLabel: AppLocalizations.of(context).retryVaccinations,
            onRetry: load,
          ),
          _ => Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: AppLocalizations.of(
                  context,
                ).loadingLinkedVaccinations,
              ),
            ),
          ),
        },
      ),
    );
  }
}
