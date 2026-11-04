import 'training.dart';

class WorkoutHistoryEntry {
  const WorkoutHistoryEntry({
    this.id,
    this.completedAt,
    required this.trainingId,
    required this.trainingName,
    required this.exercises,
  });

  final String? id;
  final DateTime? completedAt;
  final String trainingId;
  final String trainingName;
  final List<WorkoutHistoryExercise> exercises;

  factory WorkoutHistoryEntry.fromTraining(
    Training training, {
    List<List<WorkoutHistorySet>> setsByExercise = const [],
  }) {
    final trainingId = training.id;
    if (trainingId == null) {
      throw StateError('A saved workout must have an id');
    }

    return WorkoutHistoryEntry(
      trainingId: trainingId,
      trainingName: training.name,
      exercises: [
        for (var index = 0; index < training.exercises.length; index++)
          WorkoutHistoryExercise.fromTrainingExercise(
            training.exercises[index],
            sets: index < setsByExercise.length
                ? setsByExercise[index]
                : const [],
          ),
      ],
    );
  }

  factory WorkoutHistoryEntry.fromJson(Map<String, dynamic> json) =>
      WorkoutHistoryEntry(
        id: json['id']?.toString(),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
        trainingId: json['trainingId']?.toString() ?? '',
        trainingName: json['trainingName'] as String? ?? 'Entrenamiento',
        exercises: (json['exercises'] as List<dynamic>? ?? const [])
            .map((item) => WorkoutHistoryExercise.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'trainingId': trainingId,
        'trainingName': trainingName,
        'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
      };
}

class WorkoutHistoryExercise {
  const WorkoutHistoryExercise({
    this.exerciseId,
    required this.exerciseName,
    required this.orderIndex,
    required this.series,
    required this.repetitions,
    this.repetitionsMax,
    required this.repetitionType,
    required this.rpe,
    required this.measurementUnit,
    this.load,
    this.sets = const [],
  });

  final String? exerciseId;
  final String exerciseName;
  final int orderIndex;
  final int series;
  // Copia de la plantilla: pueden ser nulos si la plantilla no los define.
  final int? repetitions;
  final int? repetitionsMax;
  final TrainingRepetitionType repetitionType;
  final int? rpe;
  final TrainingLoadUnit measurementUnit;
  final double? load;
  final List<WorkoutHistorySet> sets;

  factory WorkoutHistoryExercise.fromTrainingExercise(
    TrainingExercise exercise, {
    List<WorkoutHistorySet> sets = const [],
  }) =>
      WorkoutHistoryExercise(
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.exerciseName,
        orderIndex: exercise.orderIndex,
        series: exercise.series,
        repetitions: exercise.repetitions,
        repetitionsMax: exercise.repetitionsMax,
        repetitionType: exercise.repetitionType,
        rpe: exercise.rpe,
        measurementUnit: exercise.measurementUnit,
        load: exercise.load,
        sets: sets,
      );

  factory WorkoutHistoryExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutHistoryExercise(
        exerciseId: json['exerciseId']?.toString(),
        exerciseName: json['exerciseName'] as String? ?? 'Ejercicio',
        orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
        series: (json['series'] as num?)?.toInt() ?? 1,
        repetitions: (json['repetitions'] as num?)?.toInt(),
        repetitionsMax: (json['repetitionsMax'] as num?)?.toInt(),
        repetitionType: json['repetitionType'] == 'RANGE'
            ? TrainingRepetitionType.range
            : TrainingRepetitionType.fixed,
        rpe: (json['rpe'] as num?)?.toInt(),
        measurementUnit: switch (json['measurementUnit']) {
          'LB' => TrainingLoadUnit.lb,
          'BODY_WEIGHT' => TrainingLoadUnit.bodyWeight,
          _ => TrainingLoadUnit.kg,
        },
        load: (json['load'] as num?)?.toDouble(),
        sets: (json['sets'] as List<dynamic>? ?? const [])
            .map((item) => WorkoutHistorySet.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'orderIndex': orderIndex,
        'series': series,
        'repetitions': repetitions,
        'repetitionsMax': repetitionsMax,
        'repetitionType': repetitionType.name.toUpperCase(),
        'rpe': rpe,
        'measurementUnit': switch (measurementUnit) {
          TrainingLoadUnit.kg => 'KG',
          TrainingLoadUnit.lb => 'LB',
          TrainingLoadUnit.bodyWeight => 'BODY_WEIGHT',
        },
        'load': load,
        'sets': sets.map((set) => set.toJson()).toList(),
      };
}

class WorkoutHistorySet {
  const WorkoutHistorySet({
    required this.setNumber,
    required this.repetitions,
    this.load,
  });

  final int setNumber;
  final int repetitions;
  final double? load;

  factory WorkoutHistorySet.fromJson(Map<String, dynamic> json) =>
      WorkoutHistorySet(
        setNumber: (json['setNumber'] as num?)?.toInt() ?? 1,
        repetitions: (json['repetitions'] as num?)?.toInt() ?? 1,
        load: (json['load'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'repetitions': repetitions,
        'load': load,
      };
}
