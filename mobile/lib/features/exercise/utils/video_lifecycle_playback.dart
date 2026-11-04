import 'package:flutter/widgets.dart';

enum VideoLifecycleAction { none, pause, resume }

class VideoLifecyclePlayback {
  bool _pausedForLifecycle = false;
  bool _wasPlayingBeforeLifecyclePause = false;

  VideoLifecycleAction handle(AppLifecycleState state, bool isPlaying) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (!_pausedForLifecycle) {
          _wasPlayingBeforeLifecyclePause = isPlaying;
          _pausedForLifecycle = true;
        }
        return VideoLifecycleAction.pause;
      case AppLifecycleState.resumed:
        final shouldResume =
            _pausedForLifecycle && _wasPlayingBeforeLifecyclePause;
        _pausedForLifecycle = false;
        _wasPlayingBeforeLifecyclePause = false;
        return shouldResume
            ? VideoLifecycleAction.resume
            : VideoLifecycleAction.none;
      case AppLifecycleState.detached:
        return VideoLifecycleAction.none;
    }
  }
}