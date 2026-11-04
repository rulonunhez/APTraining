import 'package:flutter/material.dart';

import '../models/training.dart';
import '../models/workout_history_entry.dart';
import '../utils/date_format.dart';

/// Detalle de un registro del historial: todos los ejercicios realizados
/// con los datos de cada serie.
class WorkoutHistoryDetailScreen extends StatelessWidget {
  const WorkoutHistoryDetailScreen({super.key, required this.entry});

  final WorkoutHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(entry.trainingName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (entry.completedAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  formatDateTime(entry.completedAt!.toLocal()),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            for (final exercise in entry.exercises) ...[
              _ExerciseDetailCard(exercise: exercise),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseDetailCard extends StatelessWidget {
  const _ExerciseDetailCard({required this.exercise});

  final WorkoutHistoryExercise exercise;

  String get _templateLabel {
    final parts = <String>['${exercise.series} series'];
    final repetitions = exercise.repetitions;
    if (repetitions != null) {
      final max = exercise.repetitionsMax;
      final range = exercise.repetitionType == TrainingRepetitionType.range &&
              max != null
          ? '$repetitions-$max'
          : '$repetitions';
      parts.add('$range reps');
    }
    if (exercise.rpe != null) parts.add('RPE ${exercise.rpe}');
    return parts.join(' · ');
  }

  String _loadLabel(WorkoutHistorySet set) {
    if (exercise.measurementUnit == TrainingLoadUnit.bodyWeight) {
      return 'Peso corporal';
    }
    final load = set.load;
    if (load == null) return '—';
    final unit = exercise.measurementUnit == TrainingLoadUnit.lb ? 'lb' : 'kg';
    final value = load == load.roundToDouble() ? '${load.toInt()}' : '$load';
    return '$value $unit';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.exerciseName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              _templateLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final set in exercise.sets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        'Serie ${set.setNumber}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Text('${set.repetitions} reps')),
                    Text(
                      _loadLabel(set),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
