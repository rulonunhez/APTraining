import 'package:flutter/material.dart';
import '../../../shared/widgets/floating_nav_metrics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ap_training/core/widgets/app_loader.dart';

import '../../planning/models/training_plan.dart';
import '../../planning/providers/training_plans_provider.dart';
import '../models/training.dart';
import '../providers/trainings_provider.dart';

class WorkoutModeScreen extends ConsumerWidget {
  const WorkoutModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingsAsync = ref.watch(trainingsProvider);
    final plansAsync = ref.watch(trainingPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: trainingsAsync.isLoading || plansAsync.isLoading
          ? const Center(child: AppLoader())
          : trainingsAsync.hasError || plansAsync.hasError
              ? _LoadError(onRetry: () => _refresh(ref))
              : _buildTrainingList(
                  context,
                  trainingsAsync.valueOrNull ?? const [],
                  plansAsync.valueOrNull ?? const [],
                  onRefresh: () => _refresh(ref),
                ),
    );
  }

  Widget _buildTrainingList(
      BuildContext context, List<Training> trainings, List<TrainingPlan> plans,
      {required Future<void> Function() onRefresh}) {
    final today = DateUtils.dateOnly(DateTime.now());
    final scheduled = _scheduledTrainings(trainings, plans, today);
    final scheduledIds = scheduled.map((item) => item.training.id).toSet();
    final otherTrainings = trainings
        .where((training) => !scheduledIds.contains(training.id))
        .toList()
      ..sort((first, second) =>
          first.name.toLowerCase().compareTo(second.name.toLowerCase()));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 24 + floatingNavBarClearance(context)),
        children: [
          _SectionHeading(
            title: 'Programados para hoy',
            count: scheduled.length,
          ),
          if (scheduled.isEmpty)
            const _EmptySection(
              message: 'No hay entrenamientos programados para hoy',
            )
          else
            for (final item in scheduled)
              _TrainingChoiceTile(
                training: item.training,
                contextLabel: item.contexts.join(' · '),
                onTap: () => _openSession(context, item.training),
              ),
          const SizedBox(height: 24),
          _SectionHeading(
            title: 'Otros entrenamientos',
            count: otherTrainings.length,
          ),
          if (otherTrainings.isEmpty)
            _EmptySection(
              message: trainings.isEmpty
                  ? 'Aún no tienes entrenamientos creados'
                  : 'Todos tus entrenamientos están programados para hoy',
            )
          else
            for (final training in otherTrainings)
              _TrainingChoiceTile(
                training: training,
                contextLabel: training.createdByMe
                    ? null
                    : 'De un plan asignado por tu entrenador',
                onTap: () => _openSession(context, training),
              ),
        ],
      ),
    );
  }

  void _openSession(BuildContext context, Training training) {
    final id = training.id;
    if (id == null) return;
    context.push('/workout/session/$id', extra: training);
  }

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(trainingsProvider.notifier).refresh(),
      ref.read(trainingPlansProvider.notifier).refresh(),
    ]);
  }
}

class _ScheduledTraining {
  const _ScheduledTraining({
    required this.training,
    required this.contexts,
    required this.sortMinute,
  });

  final Training training;
  final List<String> contexts;
  final int sortMinute;
}

class _ScheduledTrainingAccumulator {
  _ScheduledTrainingAccumulator(this.training);

  final Training training;
  final Set<String> contexts = {};
  int sortMinute = 24 * 60;
}

List<_ScheduledTraining> _scheduledTrainings(
  List<Training> trainings,
  List<TrainingPlan> plans,
  DateTime date,
) {
  final trainingsById = {
    for (final training in trainings)
      if (training.id != null) training.id!: training,
  };
  final scheduledById = <String, _ScheduledTrainingAccumulator>{};

  for (final plan in plans) {
    if (!plan.isActiveOn(date)) continue;

    for (final workout in plan.workouts) {
      if (!workout.isScheduledOn(date)) continue;
      final training = trainingsById[workout.trainingId];
      if (training == null) continue;

      final accumulator = scheduledById.putIfAbsent(
        workout.trainingId,
        () => _ScheduledTrainingAccumulator(training),
      );
      for (final schedule in workout.schedules) {
        if (schedule.dayOfWeek.index != date.weekday - 1) continue;
        final minute = schedule.startMinuteOfDay ?? 24 * 60;
        if (minute < accumulator.sortMinute) accumulator.sortMinute = minute;
        accumulator.contexts.add(
          '${plan.name} · ${_scheduleLabel(schedule)}',
        );
      }
    }
  }

  final result = scheduledById.values
      .map(
        (item) => _ScheduledTraining(
          training: item.training,
          contexts: item.contexts.toList()..sort(),
          sortMinute: item.sortMinute,
        ),
      )
      .toList()
    ..sort((first, second) {
      final byTime = first.sortMinute.compareTo(second.sortMinute);
      if (byTime != 0) return byTime;
      return first.training.name
          .toLowerCase()
          .compareTo(second.training.name.toLowerCase());
    });
  return result;
}

String _scheduleLabel(TrainingPlanSchedule schedule) {
  final start = schedule.startMinuteOfDay;
  final end = schedule.endMinuteOfDay;
  if (start == null || end == null) return 'Hora flexible';
  return '${_formatMinute(start)} - ${_formatMinute(end)}';
}

String _formatMinute(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:'
    '${(value % 60).toString().padLeft(2, '0')}';

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Text('$count'),
          ],
        ),
      );
}

class _TrainingChoiceTile extends StatelessWidget {
  const _TrainingChoiceTile({
    required this.training,
    required this.onTap,
    this.contextLabel,
  });

  final Training training;
  final VoidCallback onTap;
  final String? contextLabel;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          leading: const Icon(Icons.fitness_center),
          title: Text(training.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${training.exercises.length} ejercicios',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (contextLabel != null)
                Text(
                  contextLabel!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('No se pudieron cargar los entrenamientos'),
        ),
      );
}
