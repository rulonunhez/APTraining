import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../../exercise/models/exercise_video_source.dart';
import '../models/workout_step.dart';

enum WorkoutVideoStatus { loading, ready, error }

class WorkoutVideoSlot {
  WorkoutVideoSlot(this.status, [this.controller]);

  WorkoutVideoStatus status;
  VideoPlayerController? controller;
}

typedef WorkoutVideoControllerFactory = VideoPlayerController Function(Uri uri);

/// Mantiene inicializados solo los vídeos subidos del ejercicio activo y sus
/// vecinos; el resto se libera. Los vídeos de YouTube no pasan por el pool.
class WorkoutVideoPool extends ChangeNotifier {
  WorkoutVideoPool({
    required this.steps,
    WorkoutVideoControllerFactory? controllerFactory,
    this.radius = 1,
  }) : _controllerFactory = controllerFactory ??
            ((uri) => VideoPlayerController.networkUrl(uri));

  final List<WorkoutStep> steps;
  final int radius;
  final WorkoutVideoControllerFactory _controllerFactory;
  final Map<int, WorkoutVideoSlot> _slots = {};
  int _active = 0;
  bool _foreground = true;
  bool _manuallyPaused = false;
  bool _disposed = false;

  WorkoutVideoSlot? slotAt(int index) => _slots[index];

  /// Espera solo al vídeo activo; los vecinos se cargan en segundo plano.
  Future<void> setActive(int index) async {
    _active = index;
    _manuallyPaused = false;

    final wanted = {
      for (var i = index - radius; i <= index + radius; i++)
        if (_isUpload(i)) i,
    };
    for (final i in _slots.keys.where((i) => !wanted.contains(i)).toList()) {
      _release(i);
    }
    for (final i in wanted.where((i) => i != index)) {
      unawaited(_ensureLoaded(i));
    }
    if (wanted.contains(index)) await _ensureLoaded(index);
    _syncPlayback();
  }

  Future<void> retry(int index) async {
    _release(index);
    notifyListeners();
    await _ensureLoaded(index);
  }

  Future<void> togglePlayback(int index) async {
    final controller = _slots[index]?.controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      _manuallyPaused = true;
      await controller.pause();
    } else {
      _manuallyPaused = false;
      await controller.play();
    }
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    _syncPlayback();
  }

  bool _isUpload(int index) =>
      index >= 0 &&
      index < steps.length &&
      steps[index].videoSource == ExerciseVideoSource.upload;

  Future<void> _ensureLoaded(int index) async {
    final existing = _slots[index];
    if (existing != null && existing.status != WorkoutVideoStatus.error) return;

    final slot = WorkoutVideoSlot(WorkoutVideoStatus.loading);
    _slots[index] = slot;
    notifyListeners();

    final controller = _controllerFactory(Uri.parse(steps[index].videoUrl!));
    try {
      await controller.initialize();
      await controller.setLooping(true);
    } catch (error) {
      debugPrint('Could not load workout video: $error');
      await _disposeController(controller);
      if (!_disposed && identical(_slots[index], slot)) {
        slot.status = WorkoutVideoStatus.error;
        notifyListeners();
      }
      return;
    }

    if (_disposed || !identical(_slots[index], slot)) {
      await _disposeController(controller);
      return;
    }
    slot.controller = controller;
    slot.status = WorkoutVideoStatus.ready;
    notifyListeners();
    _syncPlayback();
  }

  void _syncPlayback() {
    if (_disposed) return;
    for (final entry in _slots.entries) {
      final controller = entry.value.controller;
      if (controller == null) continue;
      final shouldPlay =
          entry.key == _active && _foreground && !_manuallyPaused;
      unawaited(shouldPlay ? controller.play() : controller.pause());
    }
  }

  void _release(int index) {
    final controller = _slots.remove(index)?.controller;
    if (controller != null) unawaited(_disposeController(controller));
  }

  Future<void> _disposeController(VideoPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (error) {
      debugPrint('Could not dispose workout video: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final index in _slots.keys.toList()) {
      _release(index);
    }
    super.dispose();
  }
}
