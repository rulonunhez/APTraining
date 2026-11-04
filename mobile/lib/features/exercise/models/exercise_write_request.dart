import 'exercise_video_source.dart';

class ExerciseWriteRequest {
  final String name;
  final int? exerciseTypeId;
  final int? movementPatternId;
  final List<int> primaryMuscleGroupIds;
  final List<int> secondaryMuscleGroupIds;
  final List<int> equipmentIds;
  final String? explanation;
  final String? tips;
  final String? commonMistakes;
  final ExerciseVideoSource videoSource;
  final String? youtubeUrl;
  final String? uploadedVideoKey;
  final String? uploadedVideoName;

  const ExerciseWriteRequest({
    required this.name,
    this.exerciseTypeId,
    this.movementPatternId,
    this.primaryMuscleGroupIds = const [],
    this.secondaryMuscleGroupIds = const [],
    this.equipmentIds = const [],
    this.explanation,
    this.tips,
    this.commonMistakes,
    this.videoSource = ExerciseVideoSource.none,
    this.youtubeUrl,
    this.uploadedVideoKey,
    this.uploadedVideoName,
  });

  ExerciseWriteRequest withUploadedVideo(String key, String videoName) =>
      ExerciseWriteRequest(
        name: name,
        exerciseTypeId: exerciseTypeId,
        movementPatternId: movementPatternId,
        primaryMuscleGroupIds: primaryMuscleGroupIds,
        secondaryMuscleGroupIds: secondaryMuscleGroupIds,
        equipmentIds: equipmentIds,
        explanation: explanation,
        tips: tips,
        commonMistakes: commonMistakes,
        videoSource: videoSource,
        youtubeUrl: youtubeUrl,
        uploadedVideoKey: key,
        uploadedVideoName: videoName,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'exerciseTypeId': exerciseTypeId,
        'movementPatternId': movementPatternId,
        'primaryMuscleGroupIds': primaryMuscleGroupIds,
        'secondaryMuscleGroupIds': secondaryMuscleGroupIds,
        'equipmentIds': equipmentIds,
        'explanation': explanation,
        'tips': tips,
        'commonMistakes': commonMistakes,
        'videoSource': videoSource.name,
        'youtubeUrl': youtubeUrl,
        'uploadedVideoKey': uploadedVideoKey,
        'uploadedVideoName': uploadedVideoName,
      };
}