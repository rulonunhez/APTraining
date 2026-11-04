import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_loader.dart';
import '../../exercise/models/exercise.dart';
import '../../exercise/models/exercise_catalogs.dart';
import '../../exercise/providers/exercises_provider.dart';
import '../../exercise/widgets/muscle_group_filter.dart';

/// Barra de filtros de la pantalla de entrenamientos: toggle de planificados,
/// selector múltiple de ejercicios y selector múltiple de grupo muscular.
/// "Limpiar" solo resetea ejercicios y grupos musculares.
class WorkoutFilterBar extends StatelessWidget {
  const WorkoutFilterBar({
    super.key,
    required this.selectedExercises,
    required this.selectedMuscleGroups,
    required this.onExercisesChanged,
    required this.onMuscleGroupsChanged,
    required this.onClear,
    required this.plannedOnly,
    required this.onPlannedChanged,
    this.plannedEnabled = true,
    this.muscleGroupsEnabled = true,
  });

  final List<Exercise> selectedExercises;
  final List<CatalogItem> selectedMuscleGroups;
  final ValueChanged<List<Exercise>> onExercisesChanged;
  final ValueChanged<List<CatalogItem>> onMuscleGroupsChanged;
  final VoidCallback onClear;
  final bool plannedOnly;
  final ValueChanged<bool> onPlannedChanged;

  /// Los toggles y filtros necesitan datos cargados (planificaciones,
  /// ejercicios y catálogo de grupos) para cruzarlos con los entrenamientos.
  final bool plannedEnabled;
  final bool muscleGroupsEnabled;

  bool get _hasActiveFilters =>
      selectedExercises.isNotEmpty || selectedMuscleGroups.isNotEmpty;

  String get _exerciseLabel {
    if (selectedExercises.isEmpty) return 'Ejercicio';
    if (selectedExercises.length == 1) return selectedExercises.first.name;
    return '${selectedExercises.length} ejercicios';
  }

  void _pickExercises(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExerciseFilterPicker(
        selected: selectedExercises,
        onChanged: onExercisesChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          FilterChip(
            showCheckmark: false,
            avatar: const Icon(Icons.event_note, size: 18),
            label: const Text('Planificados'),
            selected: plannedOnly,
            onSelected: plannedEnabled ? onPlannedChanged : null,
          ),
          const SizedBox(width: 8),
          FilterChip(
            showCheckmark: false,
            avatar: const Icon(Icons.fitness_center, size: 18),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(_exerciseLabel, overflow: TextOverflow.ellipsis),
            ),
            selected: selectedExercises.isNotEmpty,
            onSelected: (_) => _pickExercises(context),
            onDeleted: selectedExercises.isNotEmpty
                ? () => onExercisesChanged(const <Exercise>[])
                : null,
          ),
          const SizedBox(width: 8),
          MuscleGroupFilterChip(
            selected: selectedMuscleGroups,
            onChanged: onMuscleGroupsChanged,
            enabled: muscleGroupsEnabled,
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: onClear,
              child: const Text('Limpiar'),
            ),
          ],
        ],
      ),
    );
  }
}


/// Bottom sheet multi-selección de ejercicios creados, con buscador.
/// La selección se aplica en vivo a través de [onChanged].
class _ExerciseFilterPicker extends ConsumerStatefulWidget {
  const _ExerciseFilterPicker({
    required this.selected,
    required this.onChanged,
  });

  final List<Exercise> selected;
  final ValueChanged<List<Exercise>> onChanged;

  @override
  ConsumerState<_ExerciseFilterPicker> createState() =>
      _ExerciseFilterPickerState();
}

class _ExerciseFilterPickerState
    extends ConsumerState<_ExerciseFilterPicker> {
  String _query = '';
  late List<Exercise> _selected = List.of(widget.selected);

  bool _isSelected(Exercise exercise) =>
      _selected.any((item) => item.id == exercise.id);

  void _toggle(Exercise exercise) {
    setState(() {
      if (_isSelected(exercise)) {
        _selected.removeWhere((item) => item.id == exercise.id);
      } else {
        _selected.add(exercise);
      }
    });
    widget.onChanged(List.unmodifiable(_selected));
  }

  void _clear() {
    setState(() => _selected = []);
    widget.onChanged(const []);
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtrar por ejercicio',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar ejercicio...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.toLowerCase()),
              ),
            ),
            Expanded(
              child: exercisesAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (_, __) => const Center(
                  child: Text('No se pudieron cargar los ejercicios'),
                ),
                data: (exercises) {
                  final filtered = exercises
                      .where((exercise) =>
                          exercise.name.toLowerCase().contains(_query))
                      .toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('Sin resultados'));
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final exercise = filtered[index];
                      return CheckboxListTile(
                        value: _isSelected(exercise),
                        onChanged: (_) => _toggle(exercise),
                        secondary: const Icon(Icons.fitness_center),
                        title: Text(exercise.name),
                        subtitle: exercise.primaryMuscleGroups.isEmpty
                            ? null
                            : Text(
                                exercise.primaryMuscleGroups
                                    .take(2)
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _selected.isEmpty ? null : _clear,
                    child: const Text('Limpiar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Listo'),
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
