import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise.dart';
import '../models/exercise_write_request.dart';
import '../repositories/exercise_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/exercise_remote_data_source.dart';

final exerciseRemoteDataSourceProvider = Provider<ExerciseRemoteDataSource>(
  (ref) => ExerciseRemoteDataSource(ref.watch(apiClientProvider)),
);

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => RemoteExerciseRepository(
    ref.watch(exerciseRemoteDataSourceProvider),
  ),
);

final exercisesProvider =
    AsyncNotifierProvider<ExercisesNotifier, List<Exercise>>(
  ExercisesNotifier.new,
);

class ExercisesNotifier extends AsyncNotifier<List<Exercise>> {
  @override
  Future<List<Exercise>> build() {
    ref.listen(
      authProvider.select((authState) => authState.isLoggedIn),
      (wasLoggedIn, isLoggedIn) {
        if (isLoggedIn && wasLoggedIn != true) {
          refresh();
        } else if (!isLoggedIn) {
          state = const AsyncData([]);
        }
      },
    );
    return ref.watch(exerciseRepositoryProvider).getExercises();
  }

  Future<Exercise> getExercise(String id) =>
      ref.read(exerciseRepositoryProvider).getExercise(id);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(exerciseRepositoryProvider).getExercises(),
    );
  }

  Future<void> createExercise(
    ExerciseWriteRequest request, {
    File? video,
  }) async {
    await ref
        .read(exerciseRepositoryProvider)
        .createExercise(request, video: video);
    await refresh();
  }

  Future<void> updateExercise(
    String id,
    ExerciseWriteRequest request, {
    File? video,
  }) async {
    await ref
        .read(exerciseRepositoryProvider)
        .updateExercise(id, request, video: video);
    await refresh();
  }

  Future<void> deleteExercise(String id) async {
    await ref.read(exerciseRepositoryProvider).deleteExercise(id);
    state = state.whenData(
      (exercises) => exercises.where((exercise) => exercise.id != id).toList(),
    );
  }
}
