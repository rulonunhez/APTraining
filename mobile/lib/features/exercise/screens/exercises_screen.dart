import 'package:flutter/material.dart';
import '../../../shared/widgets/floating_nav_metrics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_loader.dart';
import '../../../shared/widgets/create_button.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/slidable_delete_action.dart';
import '../../workout/providers/trainings_provider.dart';
import '../data/exercise_remote_data_source.dart';
import '../models/exercise.dart';
import '../models/exercise_catalogs.dart';
import '../providers/exercises_provider.dart';
import '../widgets/muscle_group_filter.dart';

class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  ScaffoldMessengerState? _scaffoldMessenger;
  final Set<String> _pendingDeletionIds = {};
  String search = '';
  bool _onlyWithVideo = false;
  bool _onlyInTrainings = false;
  List<CatalogItem> _selectedMuscleGroups = const [];

  @override
  void dispose() {
    _scaffoldMessenger?.clearSnackBars();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guardamos la referencia mientras el contexto aún es válido
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  void _deleteExerciseWithUndo(Exercise ex) async {
    bool undone = false;

    setState(() => _pendingDeletionIds.add(ex.id));

    _scaffoldMessenger?.clearSnackBars();
    _scaffoldMessenger?.showSnackBar(
      SnackBar(
        content: Text('${ex.name} eliminado'),
        duration: const Duration(days: 1), // lo cerramos nosotros
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            undone = true;
            if (mounted) {
              setState(() => _pendingDeletionIds.remove(ex.id));
            }
          },
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 4));

    _scaffoldMessenger?.clearSnackBars();

    if (undone) return;

    try {
      await ref.read(exercisesProvider.notifier).deleteExercise(ex.id);
      if (mounted) setState(() => _pendingDeletionIds.remove(ex.id));
    } catch (error) {
      if (mounted) {
        setState(() => _pendingDeletionIds.remove(ex.id));
        _scaffoldMessenger?.showSnackBar(
          SnackBar(
            content: Text(
              error is ExerciseApiException && error.message != null
                  ? error.message!
                  : 'No se ha podido eliminar el ejercicio',
            ),
          ),
        );
      }
    }
  }

  Widget _buildFilteredList(
    List<Exercise> exercises,
    Set<String>? usedExerciseIds,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = exercises.where((e) {
      if (_pendingDeletionIds.contains(e.id)) return false;
      final matchesSearch = e.name.toLowerCase().contains(search.toLowerCase());
      final matchesVideo = !_onlyWithVideo || e.hasVideo;
      // Si los entrenos no están cargados, el filtro no puede aplicarse.
      final matchesTraining =
          !_onlyInTrainings || (usedExerciseIds?.contains(e.id) ?? true);
      final matchesGroups = _selectedMuscleGroups
          .every((group) => e.targetsMuscleGroup(group.id));
      return matchesSearch && matchesVideo && matchesTraining && matchesGroups;
    }).toList();

    if (filtered.isEmpty) {
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

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          16, 4, 16, 16 + floatingNavBarClearance(context) + 56),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final ex = filtered[i];
        return Slidable(
          key: ValueKey(ex.id),
          closeOnScroll: true,
          endActionPane: ActionPane(
            motion: const StretchMotion(),
            extentRatio: 0.25,
            children: [
              SlidableDeleteAction(
                onPressed: () => _deleteExerciseWithUndo(ex),
              ),
            ],
          ),
          child: _ExerciseTile(
            exercise: ex,
            onTap: () => context.push('/exercises/${ex.id}/edit'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);
    final trainings = ref.watch(trainingsProvider).valueOrNull;
    final usedExerciseIds = trainings == null
        ? null
        : {
            for (final training in trainings)
              for (final item in training.exercises) item.exerciseId,
          };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicios'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.read(exercisesProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButtonLocation: const CreateButtonLocation(),
      body: exercisesAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudieron cargar los ejercicios'),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.read(exercisesProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (exercises) => Column(
          children: [
            SearchField(
              initialValue: search,
              onChanged: (value) => setState(() => search = value),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Con vídeo'),
                      selected: _onlyWithVideo,
                      onSelected: (value) =>
                          setState(() => _onlyWithVideo = value),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Con entreno'),
                      selected: _onlyInTrainings,
                      onSelected: usedExerciseIds == null
                          ? null
                          : (value) => setState(() => _onlyInTrainings = value),
                    ),
                    const SizedBox(width: 8),
                    MuscleGroupFilterChip(
                      selected: _selectedMuscleGroups,
                      onChanged: (groups) =>
                          setState(() => _selectedMuscleGroups = groups),
                    ),
                    if (_onlyWithVideo ||
                        _onlyInTrainings ||
                        _selectedMuscleGroups.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() {
                          _onlyWithVideo = false;
                          _onlyInTrainings = false;
                          _selectedMuscleGroups = const [];
                        }),
                        child: const Text('Limpiar'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(exercisesProvider.notifier).refresh(),
                child: _buildFilteredList(exercises, usedExerciseIds),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: CreateButton(
        floating: true,
        onPressed: () => context.push('/exercises/create'),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = [
      if (exercise.exerciseTypeName != null) exercise.exerciseTypeName!,
      ...exercise.primaryMuscleGroups.take(2),
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            exercise.hasVideo
                ? Icons.play_circle_outline
                : Icons.fitness_center,
            color: scheme.primary,
          ),
        ),
        title: Text(
          exercise.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              if (details.isNotEmpty) details,
              exercise.hasVideo ? 'Con vídeo' : 'Sin vídeo',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
