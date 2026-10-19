import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_related_clinical_details.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_related_records_section.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_state.dart';

class LinkedVetVisitSection extends StatelessWidget {
  final String petId;
  final String visitId;
  final String? parentClinicName;
  final String? parentVeterinarianName;
  final VoidCallback? onOpen;

  const LinkedVetVisitSection({
    super.key,
    required this.petId,
    required this.visitId,
    this.parentClinicName,
    this.parentVeterinarianName,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    void load() => context.read<VetVisitCubit>().loadVetVisit(petId, visitId);
    return AppRelatedRecordsSection(
      key: ValueKey((petId, visitId)),
      title: 'Linked vet visit',
      icon: Icons.link_outlined,
      onLoad: load,
      child: BlocBuilder<VetVisitCubit, VetVisitState>(
        builder: (context, state) => switch (state) {
          VetVisitLoaded(:final visit, :final refreshError) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (refreshError != null)
                AppErrorFeedback(
                  message: refreshError,
                  retryLabel: 'Retry visit',
                  onRetry: load,
                ),
              AppRelatedRecordTile(
                title: visit.reason,
                icon: Icons.event_note_outlined,
                openLabel: 'Open vet visit',
                onOpen: onOpen,
                details: AppRelatedClinicalDetails(
                  clinicName: visit.clinicName,
                  veterinarianName: visit.veterinarianName,
                  parentClinicName: parentClinicName,
                  parentVeterinarianName: parentVeterinarianName,
                ),
              ),
            ],
          ),
          VetVisitError(:final message) => AppErrorFeedback(
            message: message,
            retryLabel: 'Retry visit',
            onRetry: load,
          ),
          _ => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading linked vet visit',
              ),
            ),
          ),
        },
      ),
    );
  }
}
