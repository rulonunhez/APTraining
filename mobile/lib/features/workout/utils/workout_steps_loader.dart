import '../../exercise/data/exercise_remote_data_source.dart';
import '../models/training.dart';
import '../models/workout_step.dart';

/// Carga el detalle de todos los ejercicios en paralelo. Un fallo puntual no
/// bloquea el entreno: ese ejercicio queda sin detalle ni vídeo.
Future<List<WorkoutStep>> loadWorkoutSteps(
  Training training,
  ExerciseRemoteDataSource dataSource,
) {
  final exercises = [...training.exercises]
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  return Future.wait(
    exercises.map((exercise) async {
      try {
        final detail = await dataSource.getExercise(exercise.exerciseId);
        return WorkoutStep(exercise: exercise, detail: detail);
      } catch (_) {
        return WorkoutStep(exercise: exercise);
      }
    }),
  );
}
