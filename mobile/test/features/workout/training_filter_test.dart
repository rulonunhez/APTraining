import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/features/exercise/models/exercise.dart';
import 'package:ap_training/features/workout/models/training.dart';
import 'package:ap_training/features/workout/utils/training_filter.dart';

void main() {
  final pressBanca = Exercise(
    id: 'ex-1',
    name: 'Press banca',
    hasVideo: false,
    primaryMuscleGroupIds: const ['pecho'],
    secondaryMuscleGroupIds: const ['triceps'],
  );
  final sentadilla = Exercise(
    id: 'ex-2',
    name: 'Sentadilla',
    hasVideo: false,
    primaryMuscleGroupIds: const ['cuadriceps'],
  );
  final dominadas = Exercise(
    id: 'ex-3',
    name: 'Dominadas',
    hasVideo: false,
    primaryMuscleGroupIds: const ['espalda'],
    secondaryMuscleGroupIds: const ['biceps'],
  );

  final exercisesById = {
    for (final exercise in [pressBanca, sentadilla, dominadas])
      exercise.id: exercise,
  };

  TrainingExercise trainingExercise(Exercise exercise) => TrainingExercise(
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        repetitions: 10,
        repetitionType: TrainingRepetitionType.fixed,
        series: 3,
        rpe: 8,
        measurementUnit: TrainingLoadUnit.kg,
        orderIndex: 0,
      );

  final trainings = [
    Training(
      id: 't-1',
      name: 'Torso fuerza',
      exercises: [trainingExercise(pressBanca), trainingExercise(dominadas)],
    ),
    Training(
      id: 't-2',
      name: 'Pierna',
      exercises: [trainingExercise(sentadilla)],
    ),
    Training(
      id: 't-3',
      name: 'Full body',
      exercises: [
        trainingExercise(pressBanca),
        trainingExercise(sentadilla),
        trainingExercise(dominadas),
      ],
    ),
  ];

  test('filters by name case-insensitively', () {
    final result = filterTrainings(
      trainings,
      const TrainingFilter(nameQuery: 'TORSO'),
      exercisesById: exercisesById,
    );
    expect(result.map((training) => training.id), ['t-1']);
  });

  test('filters by contained exercise', () {
    final result = filterTrainings(
      trainings,
      const TrainingFilter(exerciseIds: {'ex-2'}),
      exercisesById: exercisesById,
    );
    expect(result.map((training) => training.id), ['t-2', 't-3']);
  });

  test('requires every selected exercise to be contained', () {
    final result = filterTrainings(
      trainings,
      const TrainingFilter(exerciseIds: {'ex-1', 'ex-3'}),
      exercisesById: exercisesById,
    );
    expect(result.map((training) => training.id), ['t-1', 't-3']);
  });

  test('filters by planned trainings only', () {
    final result = filterTrainings(
      trainings,
      const TrainingFilter(plannedOnly: true),
      exercisesById: exercisesById,
      plannedTrainingIds: {'t-2'},
    );
    expect(result.map((training) => training.id), ['t-2']);
  });

  test('keeps all trainings when planned filter is off', () {
    final result = filterTrainings(
      trainings,
      const TrainingFilter(),
      exercisesById: exercisesById,
      plannedTrainingIds: {'t-2'},
    );
    expect(result, hasLength(3));
  });

  test('matches a muscle group from primary or secondary groups', () {
    final result = filterTrainings(
      trainings,
      const TrainingFilter(muscleGroupIds: {'triceps'}),
      exercisesById: exercisesById,
    );
    expect(result.map((training) => training.id), ['t-1', 't-3']);
  });

  test('requires every selected muscle group to be covered', () {
    final result = filterTrainings(
      trainings,
      const TrainingFilter(muscleGroupIds: {'pecho', 'cuadriceps'}),
      exercisesById: exercisesById,
    );
    expect(result.map((training) => training.id), ['t-3']);
  });

  test('combines name, exercises, muscle groups and planned flag', () {
    final result = filterTrainings(
      trainings,
      const TrainingFilter(
        nameQuery: 'full',
        exerciseIds: {'ex-1'},
        muscleGroupIds: {'espalda'},
        plannedOnly: true,
      ),
      exercisesById: exercisesById,
      plannedTrainingIds: {'t-3'},
    );
    expect(result.map((training) => training.id), ['t-3']);
  });

  test('does not match muscle groups of unknown exercises', () {
    final result = filterTrainings(
      trainings,
      const TrainingFilter(muscleGroupIds: {'pecho'}),
      exercisesById: const {},
    );
    expect(result, isEmpty);
  });
}
