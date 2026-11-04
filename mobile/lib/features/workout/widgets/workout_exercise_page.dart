import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/training.dart';
import '../models/workout_step.dart';
import '../utils/workout_progress_controller.dart';
import '../utils/workout_video_pool.dart';
import 'workout_video_area.dart';

class WorkoutExercisePage extends StatelessWidget {
  const WorkoutExercisePage({
    super.key,
    required this.index,
    required this.total,
    required this.step,
    required this.isActive,
    required this.isLandscape,
    required this.pool,
    required this.progress,
  });

  final int index;
  final int total;
  final WorkoutStep step;
  final bool isActive;
  final bool isLandscape;
  final WorkoutVideoPool pool;
  final WorkoutProgressController progress;

  @override
  Widget build(BuildContext context) {
    final video = ListenableBuilder(
      listenable: pool,
      builder: (context, _) => WorkoutVideoArea(
        step: step,
        slot: pool.slotAt(index),
        isActive: isActive,
        onTogglePlayback: () => pool.togglePlayback(index),
        onRetry: () => pool.retry(index),
        fullscreenOverlayBuilder: (context) => _dataButton(context),
      ),
    );
    final info = _ExerciseInfo(
      index: index,
      total: total,
      step: step,
      progress: progress,
    );

    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;

    // Tablet horizontal: vídeo a la izquierda y datos con scroll a la derecha.
    if (isLandscape && isTablet) {
      return Row(
        children: [
          Expanded(child: video),
          SizedBox(
            width: (size.width * 0.35).clamp(320.0, 420.0),
            child: SafeArea(
              left: false,
              child: SingleChildScrollView(child: info),
            ),
          ),
        ],
      );
    }

    // Móvil horizontal: vídeo a pantalla completa y datos bajo demanda.
    if (isLandscape) {
      return Stack(
        fit: StackFit.expand,
        children: [
          video,
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(child: _dataButton(context)),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: video),
        info,
      ],
    );
  }

  Widget _dataButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _showDataSheet(context),
      icon: const Icon(Icons.list_alt),
      label: const Text('Datos'),
    );
  }

  void _showDataSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => SingleChildScrollView(
        child: _ExerciseInfo(
          index: index,
          total: total,
          step: step,
          progress: progress,
          showSwipeHint: false,
        ),
      ),
    );
  }
}

class _ExerciseInfo extends StatelessWidget {
  const _ExerciseInfo({
    required this.index,
    required this.total,
    required this.step,
    required this.progress,
    this.showSwipeHint = true,
  });

  final int index;
  final int total;
  final WorkoutStep step;
  final WorkoutProgressController progress;
  final bool showSwipeHint;

  @override
  Widget build(BuildContext context) {
    final exercise = step.exercise;
    final theme = Theme.of(context);
    final isLast = index == total - 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ejercicio ${index + 1} de $total',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            exercise.exerciseName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip('${exercise.series} series'),
              _MetricChip('${_repetitions(exercise)} reps'),
              _MetricChip(_load(exercise)),
              _MetricChip('RPE ${exercise.rpe ?? '—'}'),
            ],
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: progress,
            builder: (context, _) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var set = 0; set < exercise.series; set++)
                  _SetButton(
                    key: ValueKey('workout-set-$index-$set'),
                    number: set + 1,
                    done: progress.isDone(index, set),
                    onTap: () => progress.toggleSet(index, set),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (step.hasGuidance)
                TextButton.icon(
                  onPressed: () => _showGuidance(context),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Indicaciones'),
                ),
              const Spacer(),
              if (showSwipeHint) ...[
                Icon(
                  Icons.keyboard_arrow_up,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                Text(
                  isLast ? 'Desliza para finalizar' : 'Desliza para continuar',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showGuidance(BuildContext context) {
    final detail = step.detail;
    final sections = {
      'Explicación': (Icons.menu_book_outlined, detail?.explanation),
      'Consejos': (Icons.lightbulb_outline, detail?.tips),
      'Errores comunes': (Icons.warning_amber_outlined, detail?.commonMistakes),
    }..removeWhere((_, value) => value.$2 == null || value.$2!.trim().isEmpty);

    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in sections.entries) ...[
                Row(
                  children: [
                    Icon(entry.value.$1, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      entry.key,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Text(
                  entry.value.$2!,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.purpleLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _SetButton extends StatelessWidget {
  const _SetButton({
    super.key,
    required this.number,
    required this.done,
    required this.onTap,
  });

  final int number;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: done,
      label: 'Serie $number',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.purple : Colors.transparent,
            border: Border.all(color: AppColors.purple, width: 1.5),
          ),
          child: done
              ? const Icon(Icons.check, color: AppColors.ink)
              : Text('$number'),
        ),
      ),
    );
  }
}

String _repetitions(TrainingExercise exercise) {
  final min = exercise.repetitions;
  final max = exercise.repetitionsMax;
  if (exercise.repetitionType == TrainingRepetitionType.range) {
    if (min == null && max == null) return '—';
    return '${min ?? '—'}-${max ?? '—'}';
  }
  return min == null ? '—' : '$min';
}

String _load(TrainingExercise exercise) => switch (exercise.measurementUnit) {
      TrainingLoadUnit.bodyWeight => 'Peso corporal',
      TrainingLoadUnit.kg =>
        exercise.load == null ? 'Sin carga' : '${_formatLoad(exercise.load)} kg',
      TrainingLoadUnit.lb =>
        exercise.load == null ? 'Sin carga' : '${_formatLoad(exercise.load)} lb',
    };

String _formatLoad(double? load) {
  if (load == null) return '0';
  return load.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}
