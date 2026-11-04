import '../../exercise/models/exercise.dart';
import '../../exercise/models/exercise_video_source.dart';
import '../../exercise/utils/youtube_video_id.dart';
import 'training.dart';

/// Ejercicio del entreno con todo lo necesario para reproducirlo en el modo workout.
class WorkoutStep {
  const WorkoutStep({required this.exercise, this.detail});

  final TrainingExercise exercise;
  final Exercise? detail;

  String? get videoUrl {
    final url = detail?.videoUrl;
    return url == null || url.isEmpty ? null : url;
  }

  String? get youtubeVideoId => youtubeVideoIdFromUrl(videoUrl);

  ExerciseVideoSource get videoSource {
    if (videoUrl == null) return ExerciseVideoSource.none;
    return youtubeVideoId != null
        ? ExerciseVideoSource.youtube
        : ExerciseVideoSource.upload;
  }

  bool get hasGuidance =>
      _hasText(detail?.explanation) ||
      _hasText(detail?.tips) ||
      _hasText(detail?.commonMistakes);

  static bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}
