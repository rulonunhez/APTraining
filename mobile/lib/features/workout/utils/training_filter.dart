import '../../exercise/models/exercise.dart';
import '../models/training.dart';

/// Filtro de la lista de entrenamientos.
///
/// - [nameQuery]: texto buscado en el nombre del entrenamiento.
/// - [exerciseIds]: el entrenamiento debe contener todos estos ejercicios.
/// - [muscleGroupIds]: el entrenamiento debe incluir al menos un ejercicio
///   de cada grupo muscular (primario o secundario).
/// - [plannedOnly]: solo entrenamientos asignados a alguna planificación.
class TrainingFilter {
  const TrainingFilter({
    this.nameQuery = '',
    this.exerciseIds = const {},
    this.muscleGroupIds = const {},
    this.plannedOnly = false,
  });

  final String nameQuery;
  final Set<String> exerciseIds;
  final Set<String> muscleGroupIds;
  final bool plannedOnly;
}

List<Training> filterTrainings(
  List<Training> trainings,
  TrainingFilter filter, {
  required Map<String, Exercise> exercisesById,
  Set<String> plannedTrainingIds = const {},
}) {
  final query = filter.nameQuery.trim().toLowerCase();
  return trainings.where((training) {
    if (query.isNotEmpty && !training.name.toLowerCase().contains(query)) {
      return false;
    }
    if (filter.plannedOnly && !plannedTrainingIds.contains(training.id)) {
      return false;
    }
    final trainingExerciseIds =
        training.exercises.map((e) => e.exerciseId).toSet();
    if (!trainingExerciseIds.containsAll(filter.exerciseIds)) {
      return false;
    }
    for (final groupId in filter.muscleGroupIds) {
      final covered = training.exercises.any((trainingExercise) {
        final exercise = exercisesById[trainingExercise.exerciseId];
        return exercise != null && exercise.targetsMuscleGroup(groupId);
      });
      if (!covered) return false;
    }
    return true;
  }).toList();
}
