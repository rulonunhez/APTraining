import 'package:flutter/material.dart';
import '../../../shared/widgets/floating_nav_metrics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_loader.dart';
import '../../../shared/widgets/create_button.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/slidable_delete_action.dart';
import '../../workout/models/training.dart';
import '../../workout/providers/trainings_provider.dart';
import '../models/training_plan.dart';
import '../providers/training_plans_provider.dart';
import '../utils/training_plan_filter.dart';
import '../widgets/training_plan_filter_bar.dart';

enum _PlanningView { plans, week }

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  _PlanningView _selectedView = _PlanningView.plans;
  DateTime _weekAnchor = DateUtils.dateOnly(DateTime.now());
  String _planSearch = '';
  List<Training> _selectedTrainings = const [];
  TrainingPlanStatus? _planStatus;

  DateTime get _weekStart => _startOfWeek(_weekAnchor);

  void _clearPlanFilters() => setState(() {
        _selectedTrainings = const [];
        _planStatus = null;
      });

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(trainingPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planificación'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.read(trainingPlansProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButtonLocation: const CreateButtonLocation(),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SegmentedButton<_PlanningView>(
                segments: const [
                  ButtonSegment(
                    value: _PlanningView.plans,
                    icon: Icon(Icons.view_list_outlined),
                    label: Text('Planes'),
                  ),
                  ButtonSegment(
                    value: _PlanningView.week,
                    icon: Icon(Icons.calendar_view_week_outlined),
                    label: Text('Semana'),
                  ),
                ],
                selected: {_selectedView},
                onSelectionChanged: (selection) {
                  setState(() => _selectedView = selection.first);
                },
              ),
            ),
            if (_selectedView == _PlanningView.plans) ...[
              SearchField(
                initialValue: _planSearch,
                onChanged: (value) => setState(() => _planSearch = value),
              ),
              TrainingPlanFilterBar(
                trainings: ref.watch(trainingsProvider).valueOrNull,
                selectedTrainings: _selectedTrainings,
                onTrainingsChanged: (value) =>
                    setState(() => _selectedTrainings = value),
                status: _planStatus,
                onStatusChanged: (value) => setState(() => _planStatus = value),
                onClear: _clearPlanFilters,
                trainingsEnabled:
                    ref.watch(trainingsProvider).valueOrNull != null,
              ),
            ],
            Expanded(child: _buildContent(plansAsync)),
          ],
        ),
      ),
      floatingActionButton: _selectedView != _PlanningView.plans
          ? null
          : plansAsync.maybeWhen(
              data: (plans) => plans.isEmpty
                  ? null
                  : CreateButton(
                      floating: true,
                      onPressed: () => context.push('/planning/create'),
                    ),
              orElse: () => null,
            ),
    );
  }

  Widget _buildContent(AsyncValue<List<TrainingPlan>> plansAsync) =>
      plansAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (error, _) => _PlanningLoadError(
          onRetry: () => ref.read(trainingPlansProvider.notifier).refresh(),
        ),
        data: (plans) {
          if (_selectedView == _PlanningView.plans && plans.isEmpty) {
            return _EmptyPlans(
              onCreate: () => context.push('/planning/create'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(trainingPlansProvider.notifier).refresh(),
            child: _selectedView == _PlanningView.plans
                ? _buildPlanList(context, plans)
                : _WeeklyAgenda(
                    plans: plans,
                    weekStart: _weekStart,
                    onPrevious: () => setState(() {
                      _weekAnchor =
                          _weekAnchor.subtract(const Duration(days: 7));
                    }),
                    onNext: () => setState(() {
                      _weekAnchor = _weekAnchor.add(const Duration(days: 7));
                    }),
                    onToday: () => setState(() {
                      _weekAnchor = DateUtils.dateOnly(DateTime.now());
                    }),
                  ),
          );
        },
      );

  Widget _buildPlanList(BuildContext context, List<TrainingPlan> plans) {
    final filter = TrainingPlanFilter(
      nameQuery: _planSearch,
      trainingIds:
          _selectedTrainings.map((t) => t.id).whereType<String>().toSet(),
      status: _planStatus,
    );
    final filtered = filterTrainingPlans(plans, filter);

    if (filtered.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Center(child: Text('No hay planes que coincidan con los filtros')),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          16, 4, 16, 16 + floatingNavBarClearance(context) + 56),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _TrainingPlanTile(
        plan: filtered[index],
        onTap: () => context.push('/planning/${filtered[index].id}/edit'),
        onDelete: filtered[index].createdByMe
            ? () => _confirmDelete(context, ref, filtered[index])
            : null,
      ),
    );
  }
}

DateTime _startOfWeek(DateTime date) =>
    DateUtils.dateOnly(date).subtract(Duration(days: date.weekday - 1));

class _WeeklyAgenda extends StatelessWidget {
  const _WeeklyAgenda({
    required this.plans,
    required this.weekStart,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final List<TrainingPlan> plans;
  final DateTime weekStart;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final today = DateUtils.dateOnly(DateTime.now());
    final isCurrentWeek = !today.isBefore(weekStart) && !today.isAfter(weekEnd);

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding:
          EdgeInsets.fromLTRB(16, 8, 16, 24 + floatingNavBarClearance(context)),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Semana anterior',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}',
                        style: Theme.of(context).textTheme.titleSmall,
                        textAlign: TextAlign.center,
                      ),
                      if (!isCurrentWeek)
                        TextButton(
                          onPressed: onToday,
                          child: const Text('Ir a hoy'),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Semana siguiente',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          );
        }

        final date = weekStart.add(Duration(days: index - 1));
        final events = _eventsForDate(plans, date);
        final isToday = DateUtils.isSameDay(date, today);
        return _AgendaDay(
          date: date,
          events: events,
          isToday: isToday,
        );
      },
    );
  }
}

class _ScheduledWorkout {
  const _ScheduledWorkout({
    required this.plan,
    required this.workout,
    required this.schedule,
  });

  final TrainingPlan plan;
  final TrainingPlanWorkout workout;
  final TrainingPlanSlot schedule;
}

List<_ScheduledWorkout> _eventsForDate(
  List<TrainingPlan> plans,
  DateTime date,
) {
  final day = DateUtils.dateOnly(date);
  final events = <_ScheduledWorkout>[];

  for (final plan in plans) {
    if (!plan.isActiveOn(day)) continue;

    for (final workout in plan.workouts) {
      final slot = workout.slotOn(day);
      if (slot != null) {
        events.add(_ScheduledWorkout(
          plan: plan,
          workout: workout,
          schedule: slot,
        ));
      }
    }
  }

  events.sort((first, second) {
    final firstMinute = first.schedule.startMinuteOfDay ?? 24 * 60;
    final secondMinute = second.schedule.startMinuteOfDay ?? 24 * 60;
    final byTime = firstMinute.compareTo(secondMinute);
    if (byTime != 0) return byTime;
    return first.plan.name.compareTo(second.plan.name);
  });
  return events;
}

class _AgendaDay extends StatelessWidget {
  const _AgendaDay({
    required this.date,
    required this.events,
    required this.isToday,
  });

  final DateTime date;
  final List<_ScheduledWorkout> events;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_weekdayName(date.weekday)}, ${_formatDate(date)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isToday ? colors.primary : null,
                  ),
                ),
              ),
              if (isToday)
                Text(
                  'HOY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 12),
            child: Text(
              'Sin entrenamientos',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final event in events)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: Icon(
                  event.schedule.startMinuteOfDay == null
                      ? Icons.fitness_center
                      : Icons.schedule,
                  color: colors.primary,
                ),
                title: Text(
                  event.plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Text(
                  '${event.workout.trainingName ?? 'Entrenamiento'} · ${_scheduleTimeLabel(event.schedule)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: event.plan.id == null
                    ? null
                    : () => context.push('/planning/${event.plan.id}/edit'),
              ),
            ),
        const Divider(height: 1),
      ],
    );
  }
}

String _weekdayName(int weekday) => const [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ][weekday - 1];

String _scheduleTimeLabel(TrainingPlanSlot schedule) {
  if (schedule.startMinuteOfDay == null || schedule.endMinuteOfDay == null) {
    return 'Sin horario';
  }
  return '${_formatMinute(schedule.startMinuteOfDay!)} - '
      '${_formatMinute(schedule.endMinuteOfDay!)}';
}

String _formatMinute(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  TrainingPlan plan,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar planificación'),
      content: Text(
        'Se eliminará "${plan.name}" y dejará de bloquear el borrado de sus entrenamientos.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );

  if (confirmed != true || plan.id == null) return;
  try {
    await ref.read(trainingPlansProvider.notifier).deleteTrainingPlan(plan.id!);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la planificación')),
      );
    }
  }
}

class _TrainingPlanTile extends StatelessWidget {
  const _TrainingPlanTile({
    required this.plan,
    required this.onTap,
    required this.onDelete,
  });

  final TrainingPlan plan;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isFinished = plan.endDate != null &&
        DateUtils.dateOnly(plan.endDate!)
            .isBefore(DateUtils.dateOnly(DateTime.now()));
    final status = trainingPlanStatusOf(plan);
    final statusColor = switch (status) {
      TrainingPlanStatus.inProgress => colors.primary,
      TrainingPlanStatus.finished => colors.error,
      TrainingPlanStatus.upcoming => colors.tertiary,
      TrainingPlanStatus.undetermined => colors.outline,
    };
    final statusIcon = switch (status) {
      TrainingPlanStatus.inProgress => Icons.play_circle_outline,
      TrainingPlanStatus.finished => Icons.check_circle_outline,
      TrainingPlanStatus.upcoming => Icons.schedule,
      TrainingPlanStatus.undetermined => Icons.help_outline,
    };
    final validityLabel = plan.startDate == null && plan.endDate == null
        ? 'Sin límite de vigencia'
        : '${plan.startDate == null ? 'Sin fecha de inicio' : _formatDate(plan.startDate!)}'
            ' - ${plan.endDate == null ? 'Sin fecha de fin' : _formatDate(plan.endDate!)}';
    final workouts = plan.workouts;
    final preview = workouts
        .take(2)
        .map((workout) => workout.trainingName ?? 'Entrenamiento')
        .join(' · ');
    final workoutCountLabel = workouts.length == 1
        ? '1 entrenamiento'
        : '${workouts.length} entrenamientos';

    return Slidable(
      key: ValueKey(plan.id ?? plan.name),
      closeOnScroll: true,
      endActionPane: onDelete == null
          ? null
          : ActionPane(
              motion: const StretchMotion(),
              extentRatio: 0.25,
              children: [
                SlidableDeleteAction(
                  onPressed: onDelete!,
                ),
              ],
            ),
      child: Card(
        margin: EdgeInsets.zero,
        color: isFinished ? colors.errorContainer.withAlpha(105) : null,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          leading: Icon(
            isFinished ? Icons.event_busy : Icons.event_note_outlined,
            color: isFinished ? colors.error : colors.primary,
          ),
          title: Text(
            plan.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  validityLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      status.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$workoutCountLabel${preview.isEmpty ? '' : ' · $preview'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!plan.createdByMe) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 16, color: colors.secondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Asignado por ${plan.assignedByUsername ?? 'tu entrenador'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (plan.assignedUsers.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.groups_outlined,
                          size: 16, color: colors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          plan.assignedUsers.length == 1
                              ? 'Asignado a 1 usuario'
                              : 'Asignado a ${plan.assignedUsers.length} usuarios',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year.toString().padLeft(4, '0')}';

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_outlined,
                  size: 44, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text('Todavía no tienes planificaciones',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              CreateButton(
                onPressed: onCreate,
              ),
            ],
          ),
        ),
      );
}

class _PlanningLoadError extends StatelessWidget {
  const _PlanningLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudieron cargar las planificaciones'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
}
