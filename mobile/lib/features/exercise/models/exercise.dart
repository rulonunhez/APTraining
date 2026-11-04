import 'dart:convert';

class Exercise {
  final String id;
  final String name;
  final bool hasVideo;
  final String? videoUrl;

  final String? exerciseTypeName;
  final String? exerciseTypeId;
  final String? movementPatternName;
  final String? movementPatternId;

  // Nombres para mostrar en pantalla
  final List<String> primaryMuscleGroups;
  final List<String> secondaryMuscleGroups;
  final List<String> equipment;

  // IDs para enviar al backend
  final List<String> primaryMuscleGroupIds;
  final List<String> secondaryMuscleGroupIds;
  final List<String> equipmentIds;

  final String? explanation;
  final String? tips;
  final String? commonMistakes;

  Exercise({
    required this.id,
    required this.name,
    required this.hasVideo,
    this.videoUrl,
    this.exerciseTypeName,
    this.exerciseTypeId,
    this.movementPatternName,
    this.movementPatternId,
    this.primaryMuscleGroups = const [],
    this.secondaryMuscleGroups = const [],
    this.equipment = const [],
    this.primaryMuscleGroupIds = const [],
    this.secondaryMuscleGroupIds = const [],
    this.equipmentIds = const [],
    this.explanation,
    this.tips,
    this.commonMistakes,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'],
      hasVideo: json['hasVideo'] ?? false,
      exerciseTypeName: json['exerciseTypeName'],
      exerciseTypeId: json['exerciseTypeId']?.toString(),
      movementPatternName: json['movementPatternName'],
      movementPatternId: json['movementPatternId']?.toString(),
      primaryMuscleGroups: _parseNameList(json['primaryMuscleGroups']),
      secondaryMuscleGroups: _parseNameList(json['secondaryMuscleGroups']),
      equipment: _parseNameList(json['equipment']),
      primaryMuscleGroupIds: _parseIdList(json['primaryMuscleGroups']),
      secondaryMuscleGroupIds: _parseIdList(json['secondaryMuscleGroups']),
      equipmentIds: _parseIdList(json['equipment']),
      explanation: json['explanation'],
      tips: json['tips'],
      commonMistakes: json['commonMistakes'],
    );
  }

  factory Exercise.fromDetailJson(String str) {
    final json = jsonDecode(str);
    return Exercise(
      id: json['id'],
      name: json['name'],
      hasVideo: json['videoUrl'] != null,
      videoUrl: json['videoUrl'],
      exerciseTypeName: json['exerciseTypeName'],
      exerciseTypeId: json['exerciseTypeId']?.toString(),
      movementPatternName: json['movementPatternName'],
      movementPatternId: json['movementPatternId']?.toString(),
      primaryMuscleGroups: _parseNameList(json['primaryMuscleGroups']),
      secondaryMuscleGroups: _parseNameList(json['secondaryMuscleGroups']),
      equipment: _parseNameList(json['equipment']),
      primaryMuscleGroupIds: _parseIdList(json['primaryMuscleGroups']),
      secondaryMuscleGroupIds: _parseIdList(json['secondaryMuscleGroups']),
      equipmentIds: _parseIdList(json['equipment']),
      explanation: json['explanation'],
      tips: json['tips'],
      commonMistakes: json['commonMistakes'],
    );
  }

  /// Un ejercicio cubre un grupo si lo trabaja como primario o secundario.
  bool targetsMuscleGroup(String groupId) =>
      primaryMuscleGroupIds.contains(groupId) ||
      secondaryMuscleGroupIds.contains(groupId);

  // El backend devuelve lista de objetos {id, name} o lista de strings
  static List<String> _parseNameList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) {
        if (e is Map) return e['name']?.toString() ?? '';
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  static List<String> _parseIdList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) {
        if (e is Map) return e['id']?.toString() ?? '';
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  Exercise copyWith({
    String? id,
    String? name,
    String? videoUrl,
    String? exerciseTypeName,
    String? exerciseTypeId,
    String? movementPatternName,
    String? movementPatternId,
    List<String>? primaryMuscleGroups,
    List<String>? secondaryMuscleGroups,
    List<String>? equipment,
    List<String>? primaryMuscleGroupIds,
    List<String>? secondaryMuscleGroupIds,
    List<String>? equipmentIds,
    String? explanation,
    String? tips,
    String? commonMistakes,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      videoUrl: videoUrl ?? this.videoUrl,
      hasVideo: (videoUrl ?? this.videoUrl) != null,
      exerciseTypeName: exerciseTypeName ?? this.exerciseTypeName,
      exerciseTypeId: exerciseTypeId ?? this.exerciseTypeId,
      movementPatternName: movementPatternName ?? this.movementPatternName,
      movementPatternId: movementPatternId ?? this.movementPatternId,
      primaryMuscleGroups: primaryMuscleGroups ?? this.primaryMuscleGroups,
      secondaryMuscleGroups:
          secondaryMuscleGroups ?? this.secondaryMuscleGroups,
      equipment: equipment ?? this.equipment,
      primaryMuscleGroupIds:
          primaryMuscleGroupIds ?? this.primaryMuscleGroupIds,
      secondaryMuscleGroupIds:
          secondaryMuscleGroupIds ?? this.secondaryMuscleGroupIds,
      equipmentIds: equipmentIds ?? this.equipmentIds,
      explanation: explanation ?? this.explanation,
      tips: tips ?? this.tips,
      commonMistakes: commonMistakes ?? this.commonMistakes,
    );
  }
}