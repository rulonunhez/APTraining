/// Opción seleccionable de los filtros del historial: entreno o ejercicio
/// presente en el historial del usuario consultado.
class WorkoutHistoryFilterOption {
  const WorkoutHistoryFilterOption({required this.id, required this.name});

  final String id;
  final String name;

  factory WorkoutHistoryFilterOption.fromJson(Map<String, dynamic> json) =>
      WorkoutHistoryFilterOption(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
      );
}

class WorkoutHistoryFilterOptions {
  const WorkoutHistoryFilterOptions({
    this.trainings = const [],
    this.exercises = const [],
  });

  final List<WorkoutHistoryFilterOption> trainings;
  final List<WorkoutHistoryFilterOption> exercises;

  factory WorkoutHistoryFilterOptions.fromJson(Map<String, dynamic> json) =>
      WorkoutHistoryFilterOptions(
        trainings: (json['trainings'] as List<dynamic>? ?? const [])
            .map((item) => WorkoutHistoryFilterOption.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(),
        exercises: (json['exercises'] as List<dynamic>? ?? const [])
            .map((item) => WorkoutHistoryFilterOption.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(),
      );
}
