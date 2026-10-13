import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/di/injection.dart';
import 'package:petlytics/core/router/app_routes.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_detail_page.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_form_page.dart';
import 'package:petlytics/features/pet/presentation/pages/pet_list_page.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';
import 'package:petlytics/features/weight_history/presentation/cubit/weight_history_cubit.dart';
import 'package:petlytics/features/weight_history/presentation/pages/weight_entry_form_page.dart';
import 'package:petlytics/features/weight_history/presentation/pages/weight_history_page.dart';

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
              create: (context) => getIt<PetCubit>()..getPetById(petId),
              child: PetDetailPage(petId: petId),
            );
          },
          routes: [
            GoRoute(
              path: 'weight-history',
              builder: (context, state) {
                final petId = state.pathParameters['petId']!;
                return BlocProvider<WeightHistoryCubit>(
                  create: (_) =>
                      getIt<WeightHistoryCubit>()..loadWeightHistory(petId),
                  child: WeightHistoryPage(petId: petId),
                );
              },
              routes: [
                GoRoute(
                  path: 'form',
                  builder: (context, state) {
                    final petId = state.pathParameters['petId']!;
                    final entry = state.extra as WeightEntry?;
                    return BlocProvider<WeightHistoryCubit>(
                      create: (_) => getIt<WeightHistoryCubit>(),
                      child: WeightEntryFormPage(petId: petId, entry: entry),
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
