import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/workout_rest_settings.dart';
import '../models/workout_step.dart';

/// Series marcadas por ejercicio y temporizador de descanso de la sesión.
/// Marcar series es opcional: nunca bloquea el avance entre ejercicios.
class WorkoutProgressController extends ChangeNotifier {
  WorkoutProgressController({
    required List<WorkoutStep> steps,
    required this.settings,
  })  : _done = [for (final _ in steps) <int>{}],
        _series = [for (final step in steps) step.exercise.series];

  static const _extraRestTime = Duration(seconds: 10);

  final WorkoutRestSettings settings;
  final List<Set<int>> _done;
  final List<int> _series;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _restBetweenExercises = false;

  bool isDone(int step, int set) => _done[step].contains(set);

  bool get isResting => _remaining > Duration.zero;

  int get remainingSeconds => _remaining.inSeconds;

  bool get restBetweenExercises => _restBetweenExercises;

  void toggleSet(int step, int set) {
    if (!_done[step].add(set)) {
      _done[step].remove(set);
      notifyListeners();
      return;
    }
    final finishedExercise = _done[step].length >= _series[step];
    _startRest(
      finishedExercise ? settings.betweenExercises : settings.betweenSets,
      betweenExercises: finishedExercise,
    );
  }

  void skipRest() {
    _timer?.cancel();
    _remaining = Duration.zero;
    notifyListeners();
  }

  void addRestTime() {
    if (!isResting) return;
    _remaining += _extraRestTime;
    notifyListeners();
  }

  void _startRest(Duration duration, {required bool betweenExercises}) {
    _timer?.cancel();
    _restBetweenExercises = betweenExercises;
    _remaining = duration;
    notifyListeners();
    if (duration <= Duration.zero) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remaining -= const Duration(seconds: 1);
      if (_remaining <= Duration.zero) {
        _remaining = Duration.zero;
        timer.cancel();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
