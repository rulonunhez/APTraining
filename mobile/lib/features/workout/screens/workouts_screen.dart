import 'package:flutter/material.dart';
import '../../../shared/widgets/floating_nav_metrics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_loader.dart';
import '../../../shared/widgets/create_button.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/slidable_delete_action.dart';
import '../../exercise/models/exercise.dart';
import '../../exercise/models/exercise_catalogs.dart';
import '../../exercise/providers/exercises_provider.dart';
import '../../planning/models/training_plan.dart';
import '../../planning/providers/training_plans_provider.dart';
import '../data/training_remote_data_source.dart';
import '../models/training.dart';
import '../providers/trainings_provider.dart';
import '../utils/training_filter.dart';
import '../widgets/workout_filter_bar.dart';

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  String _search = '';
  List<Exercise> _selectedExercises = const [];
  List<CatalogItem> _selectedMuscleGroups = const [];
  bool _plannedOnly = false;

  void _clearFilters() => setState(() {
        _selectedExercises = const [];
        _selectedMuscleGroups = const [];
      });

  @override
  Widget build(BuildContext context) {
    final trainingsAsync = ref.watch(trainingsProvider);
    final exercises = ref.watch(exercisesProvider).valueOrNull;
    final plans = ref.watch(trainingPlansProvider).valueOrNull;
    final exercisesById = {
      for (final exercise in exercises ?? const <Exercise>[])
        exercise.id: exercise,
    };
    final plannedTrainingIds = {
      for (final plan in plans ?? const <TrainingPlan>[])
        for (final workout in plan.workouts) workout.trainingId,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamientos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.read(trainingsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButtonLocation: const CreateButtonLocation(),
      body: trainingsAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (error, _) => _LoadError(
          onRetry: () => ref.read(trainingsProvider.notifier).refresh(),
        ),
        data: (trainings) {
          // La biblioteca solo muestra los entrenos propios; los visibles por
          // un plan asignado se entrenan desde el modo Workout.
          final ownTrainings = [
            for (final training in trainings)
              if (training.createdByMe) training,
          ];
          if (ownTrainings.isEmpty) {
            return _EmptyTrainings(
              onCreate: () => context.push('/workouts/create'),
            );
          }
          final filtered = filterTrainings(
            ownTrainings,
            TrainingFilter(
              nameQuery: _search,
              exerciseIds: _selectedExercises.map((e) => e.id).toSet(),
              muscleGroupIds:
                  _selectedMuscleGroups.map((group) => group.id).toSet(),
              plannedOnly: _plannedOnly,
            ),
            exercisesById: exercisesById,
            plannedTrainingIds: plannedTrainingIds,
          );
          return Column(
            children: [
              SearchField(
                initialValue: _search,
                onChanged: (value) => setState(() => _search = value),
              ),
              WorkoutFilterBar(
                selectedExercises: _selectedExercises,
                selectedMuscleGroups: _selectedMuscleGroups,
                muscleGroupsEnabled: exercises != null,
                plannedOnly: _plannedOnly,
                plannedEnabled: plans != null,
                onPlannedChanged: (value) =>
                    setState(() => _plannedOnly = value),
                onExercisesChanged: (list) =>
                    setState(() => _selectedExercises = list),
                onMuscleGroupsChanged: (groups) =>
                    setState(() => _selectedMuscleGroups = groups),
                onClear: _clearFilters,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(trainingsProvider.notifier).refresh(),
                  child: filtered.isEmpty
                      ? const _NoResults()
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(16, 4, 16,
                              16 + floatingNavBarClearance(context) + 56),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) => _TrainingTile(
                            training: filtered[index],
                            onTap: () => context.push(
                              '/workouts/${filtered[index].id}/edit',
                            ),
                            onDelete: () => _confirmDelete(
                              context,
                              ref,
                              filtered[index],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: CreateButton(
        floating: true,
        onPressed: () => context.push('/workouts/create'),
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Training training,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar entrenamiento'),
      content:
          Text('Se eliminará "${training.name}" y su lista de ejercicios.'),
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

  if (confirmed != true || training.id == null) return;
  try {
    await ref.read(trainingsProvider.notifier).deleteTraining(training.id!);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is TrainingApiException && error.message != null
                ? error.message!
                : 'No se pudo eliminar el entrenamiento',
          ),
        ),
      );
    }
  }
}

class _TrainingTile extends StatelessWidget {
  const _TrainingTile({
    required this.training,
    required this.onTap,
    required this.onDelete,
  });

  final Training training;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercisePreview = training.exercises
        .take(3)
        .map((exercise) => exercise.exerciseName)
        .join(' · ');

    return Slidable(
      key: ValueKey(training.id ?? training.name),
      closeOnScroll: true,
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.25,
        children: [
          SlidableDeleteAction(
            onPressed: onDelete,
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          title: Text(
            training.name,
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
                if (training.description?.isNotEmpty == true)
                  Text(
                    training.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  '${training.exercises.length} ejercicios'
                  '${exercisePreview.isEmpty ? '' : ' · $exercisePreview'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTrainings extends StatelessWidget {
  const _EmptyTrainings({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center,
                  size: 44, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text('Todavía no tienes entrenamientos',
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

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        const SizedBox(height: 96),
        Icon(Icons.search_off, size: 56, color: scheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(
          'Sin resultados',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudieron cargar los entrenamientos'),
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
