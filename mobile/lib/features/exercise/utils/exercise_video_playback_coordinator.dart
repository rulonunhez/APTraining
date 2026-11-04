import 'package:flutter/foundation.dart';

class ExerciseVideoPlaybackCoordinator {
  ExerciseVideoPlaybackCoordinator._();

  static Object? _activePlayer;
  static Future<void> Function()? _pauseActivePlayer;

  static Future<void> claim(
    Object player,
    Future<void> Function() pause,
  ) async {
    if (identical(_activePlayer, player)) {
      _pauseActivePlayer = pause;
      return;
    }

    final previousPause = _pauseActivePlayer;
    _activePlayer = player;
    _pauseActivePlayer = pause;
    if (previousPause == null) return;

    try {
      await previousPause();
    } catch (error) {
      debugPrint('Could not pause the previous exercise video: $error');
    }
  }

  static void release(Object player) {
    if (!identical(_activePlayer, player)) return;
    _activePlayer = null;
    _pauseActivePlayer = null;
  }
}
