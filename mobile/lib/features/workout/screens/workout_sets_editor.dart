import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/training.dart';
import '../models/workout_history_entry.dart';

class WorkoutSetsEditor extends StatefulWidget {
  const WorkoutSetsEditor({
    super.key,
    required this.training,
    required this.onCancel,
    required this.onSave,
  });

  final Training training;
  final VoidCallback onCancel;
  final void Function(
    List<List<WorkoutHistorySet>> sets, {
    required List<TrainingExercise> exercises,
  }) onSave;

  @override
  State<WorkoutSetsEditor> createState() => _WorkoutSetsEditorState();
}

class _WorkoutSetsEditorState extends State<WorkoutSetsEditor> {
  final _formKey = GlobalKey<FormState>();
  // Ejercicios y series que realmente se registran: se pueden quitar los
  // ejercicios o series que el usuario no haya realizado.
  late final List<TrainingExercise> _exercises;
  late final List<List<_SetDraft>> _drafts;

  @override
  void initState() {
    super.initState();
    _exercises = [...widget.training.exercises];
    _drafts = [
      for (final exercise in _exercises)
        [
          for (var set = 0; set < exercise.series; set++)
            _SetDraft(
              repetitions: exercise.repetitions,
              load: exercise.load,
            ),
        ],
    ];
  }

  @override
  void dispose() {
    for (final sets in _drafts) {
      for (final draft in sets) {
        draft.dispose();
      }
    }
    super.dispose();
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    setState(() {
      _drafts[exerciseIndex].removeAt(setIndex).dispose();
    });
  }

  void _removeExercise(int exerciseIndex) {
    setState(() {
      for (final draft in _drafts[exerciseIndex]) {
        draft.dispose();
      }
      _drafts.removeAt(exerciseIndex);
      _exercises.removeAt(exerciseIndex);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    // Solo se registran los ejercicios con al menos una serie, y el número
    // de series de cada ejercicio refleja las series realmente registradas
    // (el backend exige una serie registrada por cada serie del ejercicio).
    final keptIndexes = [
      for (var index = 0; index < _drafts.length; index++)
        if (_drafts[index].isNotEmpty) index,
    ];
    if (keptIndexes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registra al menos un ejercicio con una serie'),
        ),
      );
      return;
    }
    widget.onSave(
      [
        for (final index in keptIndexes)
          [
            for (var set = 0; set < _drafts[index].length; set++)
              _drafts[index][set].toWorkoutHistorySet(
                setNumber: set + 1,
                withLoad: _exercises[index].measurementUnit !=
                    TrainingLoadUnit.bodyWeight,
              ),
          ],
      ],
      exercises: [
        for (final index in keptIndexes)
          _exerciseWithSeries(_exercises[index], _drafts[index].length),
      ],
    );
  }

  static TrainingExercise _exerciseWithSeries(
    TrainingExercise exercise,
    int series,
  ) =>
      TrainingExercise(
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.exerciseName,
        repetitions: exercise.repetitions,
        repetitionsMax: exercise.repetitionsMax,
        repetitionType: exercise.repetitionType,
        series: series,
        rpe: exercise.rpe,
        measurementUnit: exercise.measurementUnit,
        load: exercise.load,
        orderIndex: exercise.orderIndex,
        hasVideo: exercise.hasVideo,
      );

  @override
  Widget build(BuildContext context) => Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  for (var index = 0; index < _drafts.length; index++)
                    _buildExercise(index),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar series'),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildExercise(int index) {
    final exercise = _exercises[index];
    final sets = _drafts[index];
    final hasLoad = exercise.measurementUnit != TrainingLoadUnit.bodyWeight;
    final loadSuffix =
        exercise.measurementUnit == TrainingLoadUnit.kg ? 'kg' : 'lb';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(exercise.exerciseName,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'No registrar este ejercicio',
                  onPressed: () => _removeExercise(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (sets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sin series: el ejercicio no se registrará.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            for (var set = 0; set < sets.length; set++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text('Serie ${set + 1}'),
                    ),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey(
                          'workout-set-reps-${exercise.exerciseId}-$set',
                        ),
                        controller: sets[set].repetitions,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Repeticiones',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null || parsed < 1) {
                            return 'Valor no válido';
                          }
                          return null;
                        },
                      ),
                    ),
                    if (hasLoad) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(
                            'workout-set-load-${exercise.exerciseId}-$set',
                          ),
                          controller: sets[set].load,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Carga (opcional)',
                            suffixText: loadSuffix,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final parsed = double.tryParse(value);
                            if (parsed == null || parsed < 0) {
                              return 'Valor no válido';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                    IconButton(
                      tooltip: 'Quitar serie',
                      onPressed: () => _removeSet(index, set),
                      icon: const Icon(Icons.remove_circle_outline),
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

class _SetDraft {
  _SetDraft({required int? repetitions, required double? load})
      : repetitions =
            TextEditingController(text: repetitions?.toString() ?? ''),
        load = TextEditingController(text: load?.toString() ?? '');

  final TextEditingController repetitions;
  final TextEditingController load;

  WorkoutHistorySet toWorkoutHistorySet({
    required int setNumber,
    required bool withLoad,
  }) =>
      WorkoutHistorySet(
        setNumber: setNumber,
        repetitions: int.parse(repetitions.text),
        load: withLoad && load.text.trim().isNotEmpty
            ? double.parse(load.text)
            : null,
      );

  void dispose() {
    repetitions.dispose();
    load.dispose();
  }
}
