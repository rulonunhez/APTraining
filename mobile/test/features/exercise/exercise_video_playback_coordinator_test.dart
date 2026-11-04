import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/features/exercise/utils/exercise_video_playback_coordinator.dart';

void main() {
  test('pauses the previous player when another player starts', () async {
    final firstPlayer = Object();
    final secondPlayer = Object();
    final thirdPlayer = Object();
    var firstPauseCount = 0;
    var secondPauseCount = 0;

    await ExerciseVideoPlaybackCoordinator.claim(firstPlayer, () async {
      firstPauseCount++;
    });
    await ExerciseVideoPlaybackCoordinator.claim(secondPlayer, () async {
      secondPauseCount++;
    });

    expect(firstPauseCount, 1);
    expect(secondPauseCount, 0);

    ExerciseVideoPlaybackCoordinator.release(thirdPlayer);
    await ExerciseVideoPlaybackCoordinator.claim(thirdPlayer, () async {
      // The previous owner is still the second player.
    });

    expect(secondPauseCount, 1);
    ExerciseVideoPlaybackCoordinator.release(firstPlayer);
  });
}
