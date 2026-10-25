import 'package:flutter/widgets.dart';
import 'package:petlytics/core/router/pet_care_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_care_page.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_form_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_visits_cubit.dart';
import 'package:petlytics/features/medication/presentation/pages/medication_list_page.dart';
import 'package:petlytics/features/medication/presentation/pages/medication_detail_page.dart';
import 'package:petlytics/features/medication/presentation/pages/medication_form_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/core/router/pet_care_route_extra.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_state.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_detail_page.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_form_page.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_list_page.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/cubit/vaccination_form_cubit.dart';
import 'package:petlytics/features/vaccination/presentation/pages/vaccination_list_page.dart';
import 'package:petlytics/features/vaccination/presentation/pages/vaccination_detail_page.dart';
import 'package:petlytics/features/vaccination/presentation/pages/vaccination_form_page.dart';
import 'package:petlytics/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/cubit/vet_visit_form_cubit.dart';
import 'package:petlytics/features/vet_visit/presentation/pages/vet_visit_detail_page.dart';
import 'package:petlytics/features/vet_visit/presentation/pages/vet_visit_form_page.dart';
import 'package:petlytics/features/vet_visit/presentation/pages/vet_visit_list_page.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:petlytics/features/weight_history/presentation/pages/weight_entry_form_page.dart';
import 'package:petlytics/features/weight_history/presentation/pages/weight_history_page.dart';

Widget _petCarePage({
  required String petId,
  required Object? extra,
  required Widget Function(String? petName) builder,
}) {
  final petName = extra is PetCareRouteExtra && extra.petId == petId
      ? extra.petName
      : null;
  if (petName != null) return builder(petName);

  // The pet flow owns one lookup; late display context cannot replace a form.
  return BlocBuilder<PetCubit, PetState>(
    builder: (_, state) => builder(state is PetLoaded ? state.pet.name : null),
  );
}

Page<String> _careRootPage(GoRouterState state, PetCareTab tab) {
  final petId = state.pathParameters['petId']!;
  // Sibling tab routes reconcile the same page instead of pushing tab history.
  return NoTransitionPage<String>(
    key: ValueKey(('pet-care', petId)),
    child: MultiBlocProvider(
      providers: [
        BlocProvider<VetVisitCubit>(create: (_) => getIt<VetVisitCubit>()),
        BlocProvider<VaccinationCubit>(
          create: (_) => getIt<VaccinationCubit>(),
        ),
        BlocProvider<MedicationCubit>(create: (_) => getIt<MedicationCubit>()),
        BlocProvider<WeightHistoryCubit>(
          create: (_) => getIt<WeightHistoryCubit>(),
        ),
      ],
      child: PetCarePage(
        petId: petId,
        tab: tab,
        builders: {
          PetCareTab.profile: (_) => PetDetailPage(petId: petId),
          PetCareTab.vetVisits: (name) =>
              VetVisitListPage(petId: petId, petName: name),
          PetCareTab.vaccinations: (name) =>
              VaccinationListPage(petId: petId, petName: name),
          PetCareTab.medications: (name) =>
              MedicationListPage(petId: petId, petName: name),
          PetCareTab.weightHistory: (name) =>
              WeightHistoryPage(petId: petId, petName: name),
        },
      ),
    ),
  );
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.pets,
  routes: [
    GoRoute(
      path: AppRoutes.pets,
      builder: (context, state) {
        return BlocProvider<PetCubit>(
          create: (_) => getIt<PetCubit>()..loadPets(),
          child: const PetListPage(),
        );
      },
      routes: [
        GoRoute(
          path: 'form',
          builder: (context, state) {
            return BlocProvider<PetCubit>(
              create: (_) => getIt<PetCubit>(),
              child: PetFormPage(pet: state.extra as Pet?),
            );
          },
        ),

        ShellRoute(
          builder: (context, state, child) {
            final petId = state.pathParameters['petId']!;
            return BlocProvider<PetCubit>(
              key: ValueKey(petId),
              create: (_) => getIt<PetCubit>()..getPetById(petId),
              child: PetCareChangeScope(
                key: ValueKey(petId),
                petId: petId,
                child: child,
              ),
            );
          },
          routes: [
            GoRoute(
              path: ':petId',
              pageBuilder: (context, state) =>
                  _careRootPage(state, PetCareTab.profile),
            ),
            GoRoute(
              path: ':petId/medications',
              pageBuilder: (context, state) =>
                  _careRootPage(state, PetCareTab.medications),
              routes: [
                GoRoute(
                  path: 'form',
                  builder: (context, state) {
                    final petId = state.pathParameters['petId']!;
                    final extra = state.extra;
                    final valid =
                        extra is MedicationFormExtra &&
                            extra.petId == petId &&
                            (extra.medication == null ||
                                extra.medication!.petId == petId) &&
                            (extra.periodId == null ||
                                extra.medication?.periods.any(
                                      (period) => period.id == extra.periodId,
                                    ) ==
                                    true)
                        ? extra
                        : null;
                    return _petCarePage(
                      petId: petId,
                      extra: valid,
                      builder: (petName) => BlocProvider<MedicationFormCubit>(
                        key: ValueKey((
                          petId,
                          valid?.medication?.id,
                          valid?.periodId,
                          valid?.newSchedule,
                        )),
                        create: (_) => getIt<MedicationFormCubit>(),
                        child: MedicationFormPage(
                          petId: petId,
                          petName: petName,
                          medication: valid?.medication,
                          periodId: valid?.periodId,
                          newSchedule: valid?.newSchedule ?? false,
                        ),
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: ':medicationId',
                  builder: (context, state) {
                    final petId = state.pathParameters['petId']!;
                    final medicationId = state.pathParameters['medicationId']!;
                    return _petCarePage(
                      petId: petId,
                      extra: state.extra,
                      builder: (petName) => MultiBlocProvider(
                        key: ValueKey((petId, medicationId)),
                        providers: [
                          BlocProvider<MedicationCubit>(
                            create: (_) =>
                                getIt<MedicationCubit>()
                                  ..loadMedication(petId, medicationId),
                          ),
                          BlocProvider<MedicationVisitsCubit>(
                            create: (_) => getIt<MedicationVisitsCubit>(),
                          ),
                        ],
                        child: MedicationDetailPage(
                          petId: petId,
                          medicationId: medicationId,
                          petName: petName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: ':petId/vaccinations',
              pageBuilder: (context, state) =>
                  _careRootPage(state, PetCareTab.vaccinations),
              routes: [
                GoRoute(
                  path: 'form',
                  builder: (context, state) {
                    final petId = state.pathParameters['petId']!;
                    final extra = state.extra;
                    final validExtra =
                        extra is VaccinationFormExtra &&
                            extra.petId == petId &&
                            (extra.vaccination == null ||
                                extra.vaccination!.petId == petId)
                        ? extra
                        : null;
                    final vaccination = validExtra?.vaccination;
                    final recordAdministration =
                        validExtra?.recordAdministration ?? false;
                    return _petCarePage(
                      petId: petId,
                      extra: validExtra,
                      builder: (petName) => BlocProvider<VaccinationFormCubit>(
                        key: ValueKey((
                          petId,
                          vaccination?.id,
                          recordAdministration,
                        )),
                        create: (_) => getIt<VaccinationFormCubit>()
                          ..loadSuggestions(
                            clinicName: vaccination?.clinicName,
                          ),
                        child: VaccinationFormPage(
                          petId: petId,
                          petName: petName,
                          vaccination: vaccination,
                          recordAdministration: recordAdministration,
                        ),
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: ':vaccinationId',
                  builder: (context, state) {
                    final petId = state.pathParameters['petId']!;
                    final vaccinationId =
                        state.pathParameters['vaccinationId']!;
                    return _petCarePage(
                      petId: petId,
                      extra: state.extra,
                      builder: (petName) => MultiBlocProvider(
                        key: ValueKey((petId, vaccinationId)),
                        providers: [
                          BlocProvider<VaccinationCubit>(
                            create: (_) =>
                                getIt<VaccinationCubit>()
                                  ..loadVaccination(petId, vaccinationId),
                          ),
                          BlocProvider<VetVisitCubit>(
                            create: (_) => getIt<VetVisitCubit>(),
                          ),
                        ],
                        child: VaccinationDetailPage(
                          petId: petId,
                          vaccinationId: vaccinationId,
                          petName: petName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: ':petId/vet-visits',
              pageBuilder: (context, state) =>
                  _careRootPage(state, PetCareTab.vetVisits),
              routes: [
                GoRoute(
                  path: 'form',
                  builder: (context, state) {
                    final petId = state.pathParameters['petId']!;
                    final candidate = switch (state.extra) {
                      VetVisitFormExtra(:final visit) => visit,
                      VetVisit visit => visit,
                      _ => null,
                    };
                    final extra = state.extra;
                    final visit =
                        candidate?.petId == petId &&
                            (extra is! PetCareRouteExtra ||
                                extra.petId == petId)
                        ? candidate
                        : null;
                    return _petCarePage(
                      petId: petId,
                      extra: state.extra,
                      builder: (petName) => BlocProvider<VetVisitFormCubit>(
                        key: ValueKey((petId, visit?.id)),
                        create: (_) =>
                            getIt<VetVisitFormCubit>()
                              ..loadSuggestions(clinicName: visit?.clinicName),
                        child: VetVisitFormPage(
                          petId: petId,
                          visit: visit,
                          petName: petName,
                        ),
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: ':visitId',
                  builder: (context, state) {
                    final petId = state.pathParameters['petId']!;
                    final visitId = state.pathParameters['visitId']!;
                    return _petCarePage(
                      petId: petId,
                      extra: state.extra,
                      builder: (petName) => MultiBlocProvider(
                        key: ValueKey((petId, visitId)),
                        providers: [
                          BlocProvider<VetVisitCubit>(
                            create: (_) =>
                                getIt<VetVisitCubit>()
                                  ..loadVetVisit(petId, visitId),
                          ),
                          BlocProvider<VaccinationCubit>(
                            create: (_) => getIt<VaccinationCubit>(),
                          ),
                          BlocProvider<MedicationCubit>(
                            create: (_) => getIt<MedicationCubit>(),
                          ),
                        ],
                        child: VetVisitDetailPage(
                          petId: petId,
                          visitId: visitId,
                          petName: petName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: ':petId/weight-history',
              pageBuilder: (context, state) =>
                  _careRootPage(state, PetCareTab.weightHistory),
              routes: [
                GoRoute(
                  path: 'form',
                  builder: (context, state) {
                    final petId = state.pathParameters['petId']!;
                    final candidate = switch (state.extra) {
                      WeightEntryFormExtra(:final entry) => entry,
                      WeightEntry entry => entry,
                      _ => null,
                    };
                    final extra = state.extra;
                    final entry =
                        candidate?.petId == petId &&
                            (extra is! PetCareRouteExtra ||
                                extra.petId == petId)
                        ? candidate
                        : null;
                    return _petCarePage(
                      petId: petId,
                      extra: state.extra,
                      builder: (petName) => BlocProvider<WeightHistoryCubit>(
                        key: ValueKey((petId, entry?.id)),
                        create: (_) => getIt<WeightHistoryCubit>(),
                        child: WeightEntryFormPage(
                          petId: petId,
                          entry: entry,
                          petName: petName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
