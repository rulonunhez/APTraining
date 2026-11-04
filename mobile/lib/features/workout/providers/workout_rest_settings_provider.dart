import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_rest_settings.dart';

// Valores por defecto; punto de entrada para hacerlo configurable por el usuario.
final workoutRestSettingsProvider = StateProvider<WorkoutRestSettings>(
  (ref) => const WorkoutRestSettings(),
);
