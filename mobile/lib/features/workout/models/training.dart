enum TrainingRepetitionType { fixed, range }

enum TrainingLoadUnit { kg, lb, bodyWeight }

class TrainingExercise {
  const TrainingExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.repetitions,
    required this.repetitionType,
    required this.series,
    required this.rpe,
    required this.measurementUnit,
    required this.orderIndex,
    this.hasVideo = false,
    this.repetitionsMax,
    this.load,
  });

  final String exerciseId;
  final String exerciseName;
  // Repeticiones, RPE y carga son opcionales en la plantilla: el entrenado
  // registra sus valores reales en el historial.
  final int? repetitions;
  final int? repetitionsMax;
  final TrainingRepetitionType repetitionType;
  final int series;
  final int? rpe;
  final TrainingLoadUnit measurementUnit;
  final double? load;
  final int orderIndex;
  final bool hasVideo;

  factory TrainingExercise.fromJson(Map<String, dynamic> json) {
    final repetitionType = json['repetitionType'] == 'RANGE'
        ? TrainingRepetitionType.range
        : TrainingRepetitionType.fixed;
    final unit = switch (json['measurementUnit']) {
      'LB' => TrainingLoadUnit.lb,
      'BODY_WEIGHT' => TrainingLoadUnit.bodyWeight,
      _ => TrainingLoadUnit.kg,
    };

    return TrainingExercise(
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String? ?? 'Ejercicio',
      repetitions: (json['repetitions'] as num?)?.toInt(),
      repetitionsMax: (json['repetitionsMax'] as num?)?.toInt(),
      repetitionType: repetitionType,
      series: (json['series'] as num?)?.toInt() ?? 1,
      rpe: (json['rpe'] as num?)?.toInt(),
      measurementUnit: unit,
      load: (json['load'] as num?)?.toDouble(),
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
      hasVideo: json['hasVideo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'repetitions': repetitions,
        'repetitionsMax': repetitionsMax,
        'repetitionType': repetitionType.name.toUpperCase(),
        'series': series,
        'rpe': rpe,
        'measurementUnit': switch (measurementUnit) {
          TrainingLoadUnit.kg => 'KG',
          TrainingLoadUnit.lb => 'LB',
          TrainingLoadUnit.bodyWeight => 'BODY_WEIGHT',
        },
        'load': load,
        'orderIndex': orderIndex,
      };
}

class Training {
  const Training({
    this.id,
    required this.name,
    this.description,
    this.exercises = const [],
    this.createdByMe = true,
  });

  final String? id;
  final String name;
  final String? description;
  final List<TrainingExercise> exercises;

  /// false cuando el entreno se ve por estar en un plan asignado.
  final bool createdByMe;

  factory Training.fromJson(Map<String, dynamic> json) => Training(
        id: json['id'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        exercises: (json['exercises'] as List<dynamic>? ?? const [])
            .map((item) =>
                TrainingExercise.fromJson(item as Map<String, dynamic>))
            .toList(),
        createdByMe: json['createdByMe'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
      };
}
