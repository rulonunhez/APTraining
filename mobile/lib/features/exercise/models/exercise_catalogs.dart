class CatalogItem {
  final String id;
  final String code;
  final String name;

  const CatalogItem({
    required this.id,
    required this.code,
    required this.name,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
}

class ExerciseCatalogs {
  final List<CatalogItem> exerciseTypes;
  final List<CatalogItem> movementPatterns;
  final List<CatalogItem> muscleGroups;
  final List<CatalogItem> equipment;

  const ExerciseCatalogs({
    required this.exerciseTypes,
    required this.movementPatterns,
    required this.muscleGroups,
    required this.equipment,
  });

  static const empty = ExerciseCatalogs(
    exerciseTypes: [],
    movementPatterns: [],
    muscleGroups: [],
    equipment: [],
  );
}