import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/training.dart';

class WorkoutValuesEditor extends StatefulWidget {
  const WorkoutValuesEditor({
    super.key,
    required this.training,
    required this.onCancel,
    required this.onSave,
  });

  final Training training;
  final VoidCallback onCancel;
  final ValueChanged<Training> onSave;

  @override
  State<WorkoutValuesEditor> createState() => _WorkoutValuesEditorState();
}

class _WorkoutValuesEditorState extends State<WorkoutValuesEditor> {
  final _formKey = GlobalKey<FormState>();
  late final List<_ExerciseValuesDraft> _drafts;

  @override
  void initState() {
    super.initState();
    _drafts = widget.training.exercises
        .map(_ExerciseValuesDraft.fromTrainingExercise)
        .toList();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSave(
      Training(
        id: widget.training.id,
        name: widget.training.name,
        description: widget.training.description,
        exercises: [
          for (var index = 0; index < _drafts.length; index++)
            _drafts[index].toTrainingExercise(widget.training.exercises[index]),
        ],
        createdByMe: widget.training.createdByMe,
      ),
    );
  }

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
                    label: const Text('Guardar valores'),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildExercise(int index) {
    final exercise = widget.training.exercises[index];
    final draft = _drafts[index];

    Widget numberField({
      required TextEditingController controller,
      required String label,
      required String keyName,
      required bool integer,
      String? suffix,
      bool allowZero = false,
      bool optional = false,
      TextEditingController? minimumController,
    }) =>
        TextFormField(
          key: ValueKey(keyName),
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !integer),
          inputFormatters: [
            integer
                ? FilteringTextInputFormatter.digitsOnly
                : FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}'),
                  ),
          ],
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return optional ? null : 'Obligatorio';
            }
            final parsed =
                integer ? int.tryParse(value) : double.tryParse(value);
            if (parsed == null || parsed < (allowZero ? 0 : 1)) {
              return 'Valor no válido';
            }
            if (minimumController != null) {
              final minimum = int.tryParse(minimumController.text);
              if (minimum != null && parsed < minimum) {
                return 'Debe ser igual o mayor al mínimo';
              }
            }
            return null;
          },
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.exerciseName,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 110,
                  child: numberField(
                    controller: draft.series,
                    label: 'Series',
                    keyName: 'workout-series-${exercise.exerciseId}',
                    integer: true,
                  ),
                ),
                SizedBox(
                  width: 135,
                  child: numberField(
                    controller: draft.repetitions,
                    label:
                        exercise.repetitionType == TrainingRepetitionType.range
                            ? 'Mínimo reps'
                            : 'Repeticiones',
                    keyName: 'workout-repetitions-${exercise.exerciseId}',
                    integer: true,
                    optional: true,
                  ),
                ),
                if (exercise.repetitionType == TrainingRepetitionType.range)
                  SizedBox(
                    width: 135,
                    child: numberField(
                      controller: draft.repetitionsMax,
                      label: 'Máximo reps',
                      keyName: 'workout-repetitions-max-${exercise.exerciseId}',
                      integer: true,
                      optional: true,
                      minimumController: draft.repetitions,
                    ),
                  ),
                if (exercise.measurementUnit != TrainingLoadUnit.bodyWeight)
                  SizedBox(
                    width: 135,
                    child: numberField(
                      controller: draft.load,
                      label: 'Carga (opcional)',
                      keyName: 'workout-load-${exercise.exerciseId}',
                      integer: false,
                      allowZero: true,
                      optional: true,
                      suffix: exercise.measurementUnit == TrainingLoadUnit.kg
                          ? 'kg'
                          : 'lb',
                    ),
                  ),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey('workout-rpe-${exercise.exerciseId}'),
                    initialValue: draft.rpe,
                    decoration: const InputDecoration(
                      labelText: 'RPE (opcional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('—'),
                      ),
                      for (var value = 1; value <= 10; value++)
                        DropdownMenuItem<int?>(
                            value: value, child: Text('$value')),
                    ],
                    onChanged: (value) => setState(() => draft.rpe = value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseValuesDraft {
  _ExerciseValuesDraft.fromTrainingExercise(TrainingExercise exercise)
      : series = TextEditingController(text: '${exercise.series}'),
        repetitions =
            TextEditingController(text: exercise.repetitions?.toString() ?? ''),
        repetitionsMax = TextEditingController(
          text: exercise.repetitionsMax?.toString() ?? '',
        ),
        load = TextEditingController(text: exercise.load?.toString() ?? ''),
        rpe = exercise.rpe;

  final TextEditingController series;
  final TextEditingController repetitions;
  final TextEditingController repetitionsMax;
  final TextEditingController load;
  int? rpe;

  TrainingExercise toTrainingExercise(TrainingExercise original) =>
      TrainingExercise(
        exerciseId: original.exerciseId,
        exerciseName: original.exerciseName,
        repetitions: repetitions.text.trim().isEmpty
            ? null
            : int.parse(repetitions.text),
        repetitionsMax: original.repetitionType == TrainingRepetitionType.range
            ? (repetitionsMax.text.trim().isEmpty
                ? null
                : int.parse(repetitionsMax.text))
            : null,
        repetitionType: original.repetitionType,
        series: int.parse(series.text),
        rpe: rpe,
        measurementUnit: original.measurementUnit,
        load: original.measurementUnit == TrainingLoadUnit.bodyWeight
            ? null
            : (load.text.trim().isEmpty ? null : double.parse(load.text)),
        orderIndex: original.orderIndex,
        hasVideo: original.hasVideo,
      );

  void dispose() {
    series.dispose();
    repetitions.dispose();
    repetitionsMax.dispose();
    load.dispose();
  }
}
