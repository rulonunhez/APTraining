import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ap_training/features/auth/providers/auth_provider.dart';

import '../data/workout_history_remote_data_source.dart';
import '../models/workout_history_filter.dart';
import '../repositories/workout_history_repository.dart';

final workoutHistoryRemoteDataSourceProvider =
    Provider<WorkoutHistoryRemoteDataSource>(
  (ref) => WorkoutHistoryRemoteDataSource(ref.watch(apiClientProvider)),
);

final workoutHistoryRepositoryProvider = Provider<WorkoutHistoryRepository>(
  (ref) => RemoteWorkoutHistoryRepository(
    ref.watch(workoutHistoryRemoteDataSourceProvider),
  ),
);

/// Opciones de filtro (entrenos y ejercicios presentes en el historial)
/// del usuario autenticado, o del usuario indicado en modo entrenador.
final workoutHistoryFilterOptionsProvider = FutureProvider.autoDispose
    .family<WorkoutHistoryFilterOptions, String?>(
  (ref, userId) => ref
      .watch(workoutHistoryRepositoryProvider)
      .getFilterOptions(userId: userId),
);
