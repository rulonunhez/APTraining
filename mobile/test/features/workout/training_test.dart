import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/features/workout/models/training.dart';

void main() {
  test('training exercise serializes range and body weight values', () {
    const exercise = TrainingExercise(
      exerciseId: 'exercise-1',
      exerciseName: 'Flexiones',
      repetitions: 8,
      repetitionsMax: 12,
      repetitionType: TrainingRepetitionType.range,
      series: 4,
      rpe: 7,
      measurementUnit: TrainingLoadUnit.bodyWeight,
      orderIndex: 0,
    );

    final json = exercise.toJson();
    final restored = TrainingExercise.fromJson({
      ...json,
      'exerciseName': exercise.exerciseName,
      'hasVideo': true,
    });

    expect(json['repetitionType'], 'RANGE');
    expect(json['measurementUnit'], 'BODY_WEIGHT');
    expect(json['load'], isNull);
    expect(restored.repetitions, 8);
    expect(restored.repetitionsMax, 12);
    expect(restored.rpe, 7);
    expect(restored.measurementUnit, TrainingLoadUnit.bodyWeight);
    expect(restored.hasVideo, isTrue);
    expect(json.containsKey('hasVideo'), isFalse);
  });

  test('training parser keeps optional values null when absent', () {
    final training = Training.fromJson({
      'id': 'training-1',
      'name': 'Sesión anterior',
      'exercises': [
        {
          'exerciseId': 'exercise-1',
          'exerciseName': 'Sentadilla',
          'measurementUnit': 'KG',
        },
      ],
    });

    expect(training.exercises.single.series, 1);
    expect(training.exercises.single.repetitions, isNull);
    expect(training.exercises.single.rpe, isNull);
    expect(training.exercises.single.load, isNull);
    expect(training.exercises.single.hasVideo, isFalse);
  });
}
