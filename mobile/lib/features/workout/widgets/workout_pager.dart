import 'package:flutter/material.dart';

import '../models/training.dart';
import '../models/workout_step.dart';
import '../utils/workout_progress_controller.dart';
import '../utils/workout_video_pool.dart';
import 'workout_exercise_page.dart';

/// Un ejercicio por pantalla con scroll vertical en ambos sentidos; la última
/// página permite finalizar el entrenamiento.
class WorkoutPager extends StatefulWidget {
  const WorkoutPager({
    super.key,
    required this.training,
    required this.steps,
    required this.pool,
    required this.progress,
    required this.initialPage,
    required this.isLandscape,
    required this.onPageChanged,
    required this.onFinish,
  });

  final Training training;
  final List<WorkoutStep> steps;
  final WorkoutVideoPool pool;
  final WorkoutProgressController progress;
  final int initialPage;
  final bool isLandscape;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onFinish;

  @override
  State<WorkoutPager> createState() => _WorkoutPagerState();
}

class _WorkoutPagerState extends State<WorkoutPager> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _controller = PageController(initialPage: _page);
    widget.pool.setActive(_page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePageChanged(int page) {
    setState(() => _page = page);
    widget.pool.setActive(page);
    widget.onPageChanged(page);
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;

    // El descanso va fuera de la pila de vídeo: los iframes de YouTube pueden
    // pintarse por encima de los widgets superpuestos y tapar el temporizador.
    return Column(
      children: [
        _RestBanner(progress: widget.progress),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: steps.length + 1,
            onPageChanged: _handlePageChanged,
            itemBuilder: (context, index) => index == steps.length
                ? _FinishPage(
                    training: widget.training,
                    onFinish: widget.onFinish,
                  )
                : WorkoutExercisePage(
                    index: index,
                    total: steps.length,
                    step: steps[index],
                    isActive: index == _page,
                    isLandscape: widget.isLandscape,
                    pool: widget.pool,
                    progress: widget.progress,
                  ),
          ),
        ),
      ],
    );
  }
}

class _RestBanner extends StatelessWidget {
  const _RestBanner({required this.progress});

  final WorkoutProgressController progress;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        if (!progress.isResting) return const SizedBox.shrink();
        final seconds = progress.remainingSeconds;
        final time =
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    progress.restBetweenExercises
                        ? 'Descanso · $time · desliza al siguiente'
                        : 'Descanso · $time',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: progress.addRestTime,
                  child: const Text('+10 s'),
                ),
                TextButton(
                  onPressed: progress.skipRest,
                  child: const Text('Saltar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FinishPage extends StatelessWidget {
  const _FinishPage({required this.training, required this.onFinish});

  final Training training;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final totalSets = training.exercises.fold<int>(
      0,
      (total, exercise) => total + exercise.series,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Fin de ${training.name}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('${training.exercises.length} ejercicios · $totalSets series'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onFinish,
              icon: const Icon(Icons.check),
              label: const Text('Finalizar entrenamiento'),
            ),
          ],
        ),
      ),
    );
  }
}
