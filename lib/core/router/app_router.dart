import 'package:flutter/widgets.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_cubit.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_form_cubit.dart';
import 'package:patilog/features/feeding/presentation/pages/feeding_page.dart';
import 'package:patilog/features/feeding/presentation/pages/feeding_entry_form_page.dart';
import 'package:patilog/features/feeding/presentation/pages/feeding_plan_form_page.dart';
import 'package:patilog/core/router/app_navigation_observer.dart';
import 'package:patilog/core/router/care_record_changes.dart';
import 'package:patilog/features/all_pets_care/presentation/cubit/all_pets_care_cubit.dart';
import 'package:patilog/features/all_pets_care/presentation/cubit/all_pets_care_state.dart';
import 'package:patilog/features/all_pets_care/presentation/pages/all_pets_care_page.dart';
import 'package:patilog/core/router/pet_care_changes.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:patilog/features/pet/presentation/pages/pet_care_page.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_form_cubit.dart';
import 'package:patilog/features/medication/presentation/cubit/medication_visits_cubit.dart';
import 'package:patilog/features/medication/presentation/pages/medication_list_page.dart';
import 'package:patilog/features/medication/presentation/pages/medication_detail_page.dart';
import 'package:patilog/features/medication/presentation/pages/medication_form_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:patilog/core/di/injection.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/core/router/pet_care_route_extra.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:patilog/features/pet/presentation/cubit/pet_state.dart';
import 'package:patilog/features/pet/presentation/pages/pet_detail_page.dart';
import 'package:patilog/features/pet/presentation/pages/pet_form_page.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_cubit.dart';
import 'package:patilog/features/vaccination/presentation/cubit/vaccination_form_cubit.dart';
import 'package:patilog/features/vaccination/presentation/pages/vaccination_list_page.dart';
import 'package:patilog/features/vaccination/presentation/pages/vaccination_detail_page.dart';
import 'package:patilog/features/vaccination/presentation/pages/vaccination_form_page.dart';
import 'package:patilog/features/vet_visit/domain/entities/vet_visit.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_cubit.dart';
import 'package:patilog/features/vet_visit/presentation/cubit/vet_visit_form_cubit.dart';
import 'package:patilog/features/vet_visit/presentation/pages/vet_visit_detail_page.dart';
import 'package:patilog/features/vet_visit/presentation/pages/vet_visit_form_page.dart';
import 'package:patilog/features/vet_visit/presentation/pages/vet_visit_list_page.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';
import 'package:patilog/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:patilog/features/weight_history/presentation/pages/weight_entry_form_page.dart';
import 'package:patilog/features/weight_history/presentation/pages/weight_history_page.dart';
import 'package:patilog/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:patilog/features/settings/presentation/pages/settings_page.dart';
import 'package:patilog/features/notification/presentation/pages/notification_settings_page.dart';
import 'package:patilog/features/notification/presentation/cubit/notification_cubit.dart';

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
  return _PetDisplayContext(
    key: ValueKey(petId),
    petId: petId,
    builder: builder,
  );
}

class _PetDisplayContext extends StatefulWidget {
  final String petId;
  final Widget Function(String?) builder;
  const _PetDisplayContext({
    super.key,
    required this.petId,
    required this.builder,
  });
  @override
  State<_PetDisplayContext> createState() => _PetDisplayContextState();
}

class _PetDisplayContextState extends State<_PetDisplayContext> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<PetCubit>();
      if (cubit.state is PetInitial) cubit.getPetById(widget.petId);
    });
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<PetCubit, PetState>(
    builder: (_, state) =>
        widget.builder(state is PetLoaded ? state.pet.name : null),
  );
}

Page<void> _allPetsPage(AllPetsCareSection section) => NoTransitionPage<void>(
  key: const ValueKey('all-pets-care'),
  child: AllPetsCarePage(section: section),
);

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
        BlocProvider<FeedingCubit>(create: (_) => getIt<FeedingCubit>()),
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
          PetCareTab.feeding: (name) => FeedingPage(
            petId: petId,
            petName: name,
            reminder:
                state.extra is FeedingRouteExtra &&
                    (state.extra as FeedingRouteExtra).petId == petId
                ? state.extra as FeedingRouteExtra
                : null,
          ),
          PetCareTab.weightHistory: (name) =>
              WeightHistoryPage(petId: petId, petName: name),
        },
      ),
    ),
  );
}

final appNavigationChanges = ValueNotifier(0);
void _navigationChanged() => appNavigationChanges.value++;
final _rootObserver = AppNavigationObserver(_navigationChanged);
final _allPetsObserver = AppNavigationObserver(_navigationChanged);
final _petCareObserver = AppNavigationObserver(_navigationChanged);
final appNavigationObservers = [
  _rootObserver,
  _allPetsObserver,
  _petCareObserver,
];

final appRouter = GoRouter(
  observers: [_rootObserver],
  initialLocation: AppRoutes.pets,
  routes: [
    ShellRoute(
      observers: [_allPetsObserver],
      builder: (_, state, child) => MultiBlocProvider(
        providers: [
          BlocProvider<AllPetsCareCubit>(
            create: (_) => getIt<AllPetsCareCubit>(),
          ),
          BlocProvider<VetVisitCubit>(create: (_) => getIt<VetVisitCubit>()),
          BlocProvider<VaccinationCubit>(
            create: (_) => getIt<VaccinationCubit>(),
          ),
          BlocProvider<MedicationCubit>(
            create: (_) => getIt<MedicationCubit>(),
          ),
          BlocProvider<FeedingCubit>(create: (_) => getIt<FeedingCubit>()),
          BlocProvider<WeightHistoryCubit>(
            create: (_) => getIt<WeightHistoryCubit>(),
          ),
        ],
        child: CareRecordChangeScope(child: child),
      ),
      routes: [
        // Settings shares the care shell so reminder pushes cannot duplicate it.
        GoRoute(
          path: AppRoutes.settings,
          builder: (_, _) => const SettingsPage(),
          onExit: (context, _) => !context.read<SettingsCubit>().state.isBusy,
          routes: [
            GoRoute(
              path: 'notifications',
              builder: (_, _) => const NotificationSettingsPage(),
              onExit: (context, _) =>
                  !context.read<NotificationCubit>().state.isSaving,
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.healthRecords,
          redirect: (_, _) => AppRoutes.allVetVisits,
        ),
        GoRoute(
          path: AppRoutes.allWeightHistory,
          pageBuilder: (_, _) => _allPetsPage(AllPetsCareSection.weightHistory),
        ),
        GoRoute(
          path: AppRoutes.allVetVisits,
          pageBuilder: (_, _) => _allPetsPage(AllPetsCareSection.vetVisits),
        ),
        GoRoute(
          path: AppRoutes.allVaccinations,
          pageBuilder: (_, _) => _allPetsPage(AllPetsCareSection.vaccinations),
        ),
        GoRoute(
          path: AppRoutes.allMedications,
          pageBuilder: (_, _) => _allPetsPage(AllPetsCareSection.medications),
        ),
        GoRoute(
          path: AppRoutes.allFeeding,
          pageBuilder: (_, _) => _allPetsPage(AllPetsCareSection.feeding),
        ),
        GoRoute(
          path: AppRoutes.pets,
          pageBuilder: (_, _) => _allPetsPage(AllPetsCareSection.pets),
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
              observers: [_petCareObserver],
              builder: (context, state, child) {
                final petId = state.pathParameters['petId']!;
                return BlocProvider<PetCubit>(
                  key: ValueKey(petId),
                  create: (_) {
                    final cubit = getIt<PetCubit>();
                    if (PetCareTab.values.any(
                      (tab) => tab.location(petId) == state.uri.path,
                    )) {
                      cubit.getPetById(petId);
                    }
                    return cubit;
                  },
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
                  path: ':petId/feeding',
                  pageBuilder: (_, state) =>
                      _careRootPage(state, PetCareTab.feeding),
                  routes: [
                    GoRoute(
                      path: 'form',
                      builder: (_, state) {
                        final petId = state.pathParameters['petId']!;
                        final extra = state.extra;
                        final valid =
                            extra is FeedingEntryFormExtra &&
                                extra.petId == petId &&
                                (extra.entry == null ||
                                    extra.entry!.petId == petId)
                            ? extra
                            : null;
                        return _petCarePage(
                          petId: petId,
                          extra: valid ?? state.extra,
                          builder: (name) => BlocProvider<FeedingFormCubit>(
                            key: ValueKey((
                              petId,
                              'feeding-entry',
                              valid?.entry?.id,
                            )),
                            create: (_) => getIt<FeedingFormCubit>(),
                            child: FeedingEntryFormPage(
                              petId: petId,
                              petName: name,
                              entry: valid?.entry,
                            ),
                          ),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'plan/form',
                      builder: (_, state) {
                        final petId = state.pathParameters['petId']!;
                        final extra = state.extra;
                        final valid =
                            extra is FeedingPlanFormExtra &&
                                extra.petId == petId &&
                                (extra.plan == null ||
                                    extra.plan!.petId == petId) &&
                                (extra.template == null ||
                                    extra.template!.petId == petId) &&
                                (extra.plans?.every((p) => p.petId == petId) ??
                                    true)
                            ? extra
                            : null;
                        return _petCarePage(
                          petId: petId,
                          extra: valid ?? state.extra,
                          builder: (name) => BlocProvider<FeedingFormCubit>(
                            key: ValueKey((
                              petId,
                              'feeding-plan',
                              valid?.plan?.id,
                            )),
                            create: (_) => getIt<FeedingFormCubit>(),
                            child: FeedingPlanFormPage(
                              petId: petId,
                              petName: name,
                              plan: valid?.plan,
                              template: valid?.template,
                              plans: valid?.plans,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
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
                                          (period) =>
                                              period.id == extra.periodId,
                                        ) ==
                                        true)
                            ? extra
                            : null;
                        return _petCarePage(
                          petId: petId,
                          extra: valid,
                          builder: (petName) =>
                              BlocProvider<MedicationFormCubit>(
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
                        final medicationId =
                            state.pathParameters['medicationId']!;
                        final extra = state.extra;
                        final validExtra =
                            extra is MedicationDetailExtra &&
                                (extra.petId != petId ||
                                    extra.medicationId != medicationId)
                            ? null
                            : extra;
                        return _petCarePage(
                          petId: petId,
                          extra: validExtra,
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
                              initialDoseDate:
                                  validExtra is MedicationDetailExtra
                                  ? validExtra.doseDate
                                  : null,
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
                          builder: (petName) =>
                              BlocProvider<VaccinationFormCubit>(
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
                            create: (_) => getIt<VetVisitFormCubit>()
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
                          builder: (petName) =>
                              BlocProvider<WeightHistoryCubit>(
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
    ),
  ],
);
