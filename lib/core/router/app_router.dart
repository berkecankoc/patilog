import 'package:flutter/widgets.dart';
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

  // Direct URLs may have no display context; ordinary navigation supplies it.
  return BlocProvider<PetCubit>(
    key: ValueKey(petId),
    create: (_) => getIt<PetCubit>()..getPetById(petId),
    child: BlocBuilder<PetCubit, PetState>(
      builder: (_, state) =>
          builder(state is PetLoaded ? state.pet.name : null),
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

        GoRoute(
          path: ':petId',
          builder: (context, state) {
            final petId = state.pathParameters['petId']!;

            return BlocProvider(
              key: ValueKey(petId),
              create: (context) => getIt<PetCubit>()..getPetById(petId),
              child: PetDetailPage(petId: petId),
            );
          },
          routes: [
            GoRoute(
              path: 'vet-visits',
              builder: (context, state) {
                final petId = state.pathParameters['petId']!;
                return _petCarePage(
                  petId: petId,
                  extra: state.extra,
                  builder: (petName) => BlocProvider<VetVisitCubit>(
                    key: ValueKey(petId),
                    create: (_) => getIt<VetVisitCubit>()..loadVetVisits(petId),
                    child: VetVisitListPage(petId: petId, petName: petName),
                  ),
                );
              },
              routes: [
                GoRoute(
                  path: 'form',
                  builder: (context, state) {
                    final petId = state.pathParameters['petId']!;
                    final visit = switch (state.extra) {
                      VetVisitFormExtra(:final visit) => visit,
                      VetVisit visit => visit,
                      _ => null,
                    };
                    return _petCarePage(
                      petId: petId,
                      extra: state.extra,
                      builder: (petName) => BlocProvider<VetVisitFormCubit>(
                        key: ValueKey(petId),
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
                      builder: (petName) => BlocProvider<VetVisitCubit>(
                        key: ValueKey((petId, visitId)),
                        create: (_) =>
                            getIt<VetVisitCubit>()
                              ..loadVetVisit(petId, visitId),
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
              path: 'weight-history',
              builder: (context, state) {
                final petId = state.pathParameters['petId']!;
                return _petCarePage(
                  petId: petId,
                  extra: state.extra,
                  builder: (petName) => BlocProvider<WeightHistoryCubit>(
                    key: ValueKey(petId),
                    create: (_) =>
                        getIt<WeightHistoryCubit>()..loadWeightHistory(petId),
                    child: WeightHistoryPage(petId: petId, petName: petName),
                  ),
                );
              },
              routes: [
                GoRoute(
                  path: 'form',
                  builder: (context, state) {
                    final petId = state.pathParameters['petId']!;
                    final entry = switch (state.extra) {
                      WeightEntryFormExtra(:final entry) => entry,
                      WeightEntry entry => entry,
                      _ => null,
                    };
                    return _petCarePage(
                      petId: petId,
                      extra: state.extra,
                      builder: (petName) => BlocProvider<WeightHistoryCubit>(
                        key: ValueKey(petId),
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
