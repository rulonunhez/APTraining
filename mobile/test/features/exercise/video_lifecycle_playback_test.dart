import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/features/exercise/utils/video_lifecycle_playback.dart';

void main() {
  test('does not resume after the user has paused playback', () {
    final lifecycle = VideoLifecyclePlayback();

    expect(
      lifecycle.handle(AppLifecycleState.inactive, false),
      VideoLifecycleAction.pause,
    );
    expect(
      lifecycle.handle(AppLifecycleState.paused, false),
      VideoLifecycleAction.pause,
    );
    expect(
      lifecycle.handle(AppLifecycleState.resumed, false),
      VideoLifecycleAction.none,
    );
  });

  test('resumes playback if it was playing before the app was paused', () {
    final lifecycle = VideoLifecyclePlayback();

    expect(
      lifecycle.handle(AppLifecycleState.paused, true),
      VideoLifecycleAction.pause,
    );
    expect(
      lifecycle.handle(AppLifecycleState.resumed, false),
      VideoLifecycleAction.resume,
    );
  });
}