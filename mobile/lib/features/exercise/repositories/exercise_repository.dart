import 'dart:io';

import '../data/exercise_remote_data_source.dart';
import '../models/exercise.dart';
import '../models/exercise_catalogs.dart';
import '../models/exercise_write_request.dart';

abstract interface class ExerciseRepository {
  Future<List<Exercise>> getExercises();
  Future<Exercise> getExercise(String id);
  Future<ExerciseCatalogs> getCatalogs();
  Future<void> createExercise(ExerciseWriteRequest request, {File? video});
  Future<void> updateExercise(
    String id,
    ExerciseWriteRequest request, {
    File? video,
  });
  Future<void> deleteExercise(String id);
}

class RemoteExerciseRepository implements ExerciseRepository {
  final ExerciseRemoteDataSource dataSource;

  const RemoteExerciseRepository(this.dataSource);

  @override
  Future<List<Exercise>> getExercises() => dataSource.getExercises();

  @override
  Future<Exercise> getExercise(String id) => dataSource.getExercise(id);

  @override
  Future<ExerciseCatalogs> getCatalogs() => dataSource.getCatalogs();

  @override
  Future<void> createExercise(ExerciseWriteRequest request, {File? video}) =>
      dataSource.createExercise(request, video: video);

  @override
  Future<void> updateExercise(
    String id,
    ExerciseWriteRequest request, {
    File? video,
  }) =>
      dataSource.updateExercise(id, request, video: video);

  @override
  Future<void> deleteExercise(String id) => dataSource.deleteExercise(id);
}