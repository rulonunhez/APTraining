import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ap_training/features/exercise/models/exercise.dart';
import 'package:ap_training/features/exercise/providers/exercises_provider.dart';
import 'package:ap_training/core/widgets/app_loader.dart';

import '../data/training_remote_data_source.dart';
import '../models/training.dart';
import '../providers/trainings_provider.dart';

class TrainingEditorScreen extends ConsumerStatefulWidget {
  const TrainingEditorScreen({super.key, this.trainingId});

  final String? trainingId;

  @override
  ConsumerState<TrainingEditorScreen> createState() =>
      _TrainingEditorScreenState();
}

class _TrainingEditorScreenState extends ConsumerState<TrainingEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameField = _ValidatedField();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<_ExerciseDraft> _exercises = [];
  bool _loading = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.trainingId != null) {
      _loading = true;
      _loadTraining();
    }
  }

  Future<void> _loadTraining() async {
    try {
      final training = await ref
          .read(trainingsProvider.notifier)
          .getTraining(widget.trainingId!);
      if (!mounted) return;
      _nameController.text = training.name;
      _descriptionController.text = training.description ?? '';
      _exercises.addAll(training.exercises.map(_ExerciseDraft.fromTraining));
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'No se pudo cargar el entrenamiento';
        });
      }
    }
  }

  @override
  void dispose() {
    _nameField.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    for (final exercise in _exercises) {
      exercise.dispose();
    }
    super.dispose();
  }

  Future<void> _addExercise() async {
    final selected = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExercisePicker(
        excludedIds: _exercises.map((item) => item.exercise.id).toSet(),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      for (final exercise in _exercises) {
        exercise.isExpanded = false;
      }
      _exercises.add(_ExerciseDraft(selected));
    });
  }

  void _toggleExercise(int index) {
    setState(() {
      final shouldExpand = !_exercises[index].isExpanded;
      for (final exercise in _exercises) {
        exercise.isExpanded = false;
      }
      _exercises[index].isExpanded = shouldExpand;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      await _focusFirstInvalidField();
      return;
    }
    setState(() => _saving = true);

    final training = Training(
      id: widget.trainingId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      exercises: [
        for (var index = 0; index < _exercises.length; index++)
          _exercises[index].toTrainingExercise(index),
      ],
    );

    try {
      if (widget.trainingId == null) {
        await ref.read(trainingsProvider.notifier).createTraining(training);
      } else {
        await ref
            .read(trainingsProvider.notifier)
            .updateTraining(widget.trainingId!, training);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        final serverMessage =
            error is TrainingApiException ? error.message : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(serverMessage ?? 'No se pudo guardar el entrenamiento'),
          ),
        );
      }
    }
  }

  Future<void> _focusFirstInvalidField() async {
    _ExerciseDraft? invalidDraft;
    _ValidatedField? invalidField;

    if (_nameField.hasError) {
      invalidField = _nameField;
    } else {
      for (final draft in _exercises) {
        final fields = [
          draft.seriesField,
          draft.repetitionsField,
          if (draft.repetitionType == TrainingRepetitionType.range)
            draft.repetitionsMaxField,
          if (draft.measurementUnit != TrainingLoadUnit.bodyWeight)
            draft.loadField,
        ];
        for (final field in fields) {
          if (field.hasError) {
            invalidDraft = draft;
            invalidField = field;
            break;
          }
        }
        if (invalidField != null) break;
      }
    }

    if (invalidField == null) return;
    if (invalidDraft != null && !invalidDraft.isExpanded) {
      setState(() {
        for (final draft in _exercises) {
          draft.isExpanded = false;
        }
        invalidDraft!.isExpanded = true;
      });
    }

    await WidgetsBinding.instance.endOfFrame;
    final fieldContext = invalidField.key.currentContext;
    if (fieldContext == null || !fieldContext.mounted) return;
    invalidField.focusNode.requestFocus();
    await Scrollable.ensureVisible(
      fieldContext,
      alignment: 0.25,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.trainingId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar entrenamiento' : 'Nuevo entrenamiento'),
        actions: [
          IconButton(
            tooltip: 'Guardar',
            onPressed: _saving || _loading ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: AppLoader(size: 20, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: AppLoader())
          : _loadError != null
              ? Center(child: Text(_loadError!))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      TextFormField(
                        key: _nameField.key,
                        focusNode: _nameField.focusNode,
                        controller: _nameController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(),
                        ),
                        maxLength: 255,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'El nombre es obligatorio'
                                : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Ejercicios',
                                style: Theme.of(context).textTheme.titleLarge),
                          ),
                          Text('${_exercises.length}'),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Añadir ejercicio',
                            onPressed: _addExercise,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_exercises.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                              'Añade ejercicios propios a este entrenamiento.'),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _exercises.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _exercises.removeAt(oldIndex);
                              _exercises.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) => _buildExerciseCard(
                            _exercises[index],
                            index,
                          ),
                        ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(isEditing
                            ? 'Guardar cambios'
                            : 'Crear entrenamiento'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildExerciseCard(_ExerciseDraft draft, int index) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width < 390 ? 1 : 2;

    Widget numberField({
      required TextEditingController controller,
      required _ValidatedField field,
      required String label,
      required bool integer,
      String? suffix,
      TextEditingController? minimumController,
      bool allowZero = false,
      bool optional = false,
    }) {
      return TextFormField(
        key: field.key,
        focusNode: field.focusNode,
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        inputFormatters: [
          integer
              ? FilteringTextInputFormatter.digitsOnly
              : FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
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
          final parsed = integer ? int.tryParse(value) : double.tryParse(value);
          if (parsed == null || parsed < (allowZero ? 0 : 1)) {
            return 'Valor no válido';
          }
          final minimum = minimumController == null
              ? null
              : int.tryParse(minimumController.text);
          if (minimum != null && parsed < minimum) {
            return 'Debe ser igual o mayor al mínimo';
          }
          return null;
        },
      );
    }

    return Card(
      key: ValueKey(draft.exercise.id),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _toggleExercise(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draft.exercise.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            draft.summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar ejercicio',
                  onPressed: () => _removeExercise(index),
                  icon: const Icon(Icons.close),
                ),
                IconButton(
                  tooltip: draft.isExpanded
                      ? 'Plegar ejercicio'
                      : 'Desplegar ejercicio',
                  onPressed: () => _toggleExercise(index),
                  icon: Icon(
                    draft.isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ),
              ],
            ),
            Visibility(
              visible: draft.isExpanded,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: columns == 1 ? double.infinity : (width - 64) / 2,
                      child: numberField(
                        controller: draft.seriesController,
                        field: draft.seriesField,
                        label: 'Series',
                        integer: true,
                      ),
                    ),
                    SizedBox(
                      width: columns == 1 ? double.infinity : (width - 64) / 2,
                      child: DropdownButtonFormField<int?>(
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
                          for (var effort = 1; effort <= 10; effort++)
                            DropdownMenuItem<int?>(
                                value: effort, child: Text('$effort')),
                        ],
                        onChanged: (value) =>
                            setState(() => draft.rpe = value),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButtonFormField<TrainingRepetitionType>(
                        initialValue: draft.repetitionType,
                        decoration: const InputDecoration(
                          labelText: 'Repeticiones',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: TrainingRepetitionType.fixed,
                            child: Text('Fijas'),
                          ),
                          DropdownMenuItem(
                            value: TrainingRepetitionType.range,
                            child: Text('Por rango'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            draft.repetitionType = value;
                            if (value == TrainingRepetitionType.fixed) {
                              draft.repetitionsMaxController.clear();
                            }
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: draft.repetitionType ==
                              TrainingRepetitionType.range
                          ? (columns == 1 ? double.infinity : (width - 64) / 2)
                          : double.infinity,
                      child: numberField(
                        controller: draft.repetitionsController,
                        field: draft.repetitionsField,
                        label:
                            draft.repetitionType == TrainingRepetitionType.range
                                ? 'Mínimo de repeticiones (opcional)'
                                : 'Repeticiones (opcional)',
                        integer: true,
                        optional: true,
                      ),
                    ),
                    if (draft.repetitionType == TrainingRepetitionType.range)
                      SizedBox(
                        width:
                            columns == 1 ? double.infinity : (width - 64) / 2,
                        child: numberField(
                          controller: draft.repetitionsMaxController,
                          field: draft.repetitionsMaxField,
                          label: 'Máximo de repeticiones (opcional)',
                          integer: true,
                          optional: true,
                          minimumController: draft.repetitionsController,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButtonFormField<TrainingLoadUnit>(
                        initialValue: draft.measurementUnit,
                        decoration: const InputDecoration(
                          labelText: 'Carga',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: TrainingLoadUnit.kg,
                              child: Text('Kilogramos')),
                          DropdownMenuItem(
                              value: TrainingLoadUnit.lb,
                              child: Text('Libras')),
                          DropdownMenuItem(
                            value: TrainingLoadUnit.bodyWeight,
                            child: Text('Peso corporal'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            draft.measurementUnit = value;
                            if (value == TrainingLoadUnit.bodyWeight) {
                              draft.loadController.clear();
                            }
                          });
                        },
                      ),
                    ),
                    if (draft.measurementUnit != TrainingLoadUnit.bodyWeight)
                      SizedBox(
                        width: double.infinity,
                        child: numberField(
                          controller: draft.loadController,
                          field: draft.loadField,
                          label: 'Carga externa (opcional)',
                          integer: false,
                          allowZero: true,
                          optional: true,
                          suffix: draft.measurementUnit == TrainingLoadUnit.kg
                              ? 'kg'
                              : 'lb',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseDraft {
  _ExerciseDraft(this.exercise);

  factory _ExerciseDraft.fromTraining(TrainingExercise trainingExercise) {
    final draft = _ExerciseDraft(
      Exercise(
        id: trainingExercise.exerciseId,
        name: trainingExercise.exerciseName,
        hasVideo: false,
      ),
    );
    draft.seriesController.text = '${trainingExercise.series}';
    draft.repetitionsController.text =
        trainingExercise.repetitions?.toString() ?? '';
    draft.repetitionsMaxController.text =
        trainingExercise.repetitionsMax?.toString() ?? '';
    draft.repetitionType = trainingExercise.repetitionType;
    draft.rpe = trainingExercise.rpe;
    draft.measurementUnit = trainingExercise.measurementUnit;
    draft.loadController.text = trainingExercise.load?.toString() ?? '';
    draft.isExpanded = false;
    return draft;
  }

  final Exercise exercise;
  final seriesField = _ValidatedField();
  final repetitionsField = _ValidatedField();
  final repetitionsMaxField = _ValidatedField();
  final loadField = _ValidatedField();
  final seriesController = TextEditingController(text: '3');
  final repetitionsController = TextEditingController();
  final repetitionsMaxController = TextEditingController();
  final loadController = TextEditingController();
  TrainingRepetitionType repetitionType = TrainingRepetitionType.fixed;
  TrainingLoadUnit measurementUnit = TrainingLoadUnit.kg;
  int? rpe;
  bool isExpanded = true;

  String get summary {
    final min = repetitionsController.text;
    final max = repetitionsMaxController.text;
    final repetitions = repetitionType == TrainingRepetitionType.range
        ? (min.isEmpty && max.isEmpty ? '—' : '$min-$max')
        : (min.isEmpty ? '—' : min);
    final load = measurementUnit == TrainingLoadUnit.bodyWeight
        ? 'Peso corporal'
        : (loadController.text.isEmpty
            ? 'Sin carga'
            : '${loadController.text} ${measurementUnit == TrainingLoadUnit.kg ? 'kg' : 'lb'}');
    return '${seriesController.text} series · $repetitions reps · '
        'RPE ${rpe ?? '—'} · $load';
  }

  TrainingExercise toTrainingExercise(int orderIndex) => TrainingExercise(
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        repetitions: repetitionsController.text.trim().isEmpty
            ? null
            : int.parse(repetitionsController.text),
        repetitionsMax: repetitionType == TrainingRepetitionType.range
            ? (repetitionsMaxController.text.trim().isEmpty
                ? null
                : int.parse(repetitionsMaxController.text))
            : null,
        repetitionType: repetitionType,
        series: int.parse(seriesController.text),
        rpe: rpe,
        measurementUnit: measurementUnit,
        load: measurementUnit == TrainingLoadUnit.bodyWeight
            ? null
            : (loadController.text.trim().isEmpty
                ? null
                : double.parse(loadController.text)),
        orderIndex: orderIndex,
      );

  void dispose() {
    seriesField.dispose();
    repetitionsField.dispose();
    repetitionsMaxField.dispose();
    loadField.dispose();
    seriesController.dispose();
    repetitionsController.dispose();
    repetitionsMaxController.dispose();
    loadController.dispose();
  }
}

class _ValidatedField {
  final key = GlobalKey<FormFieldState<String>>();
  final focusNode = FocusNode();

  bool get hasError => key.currentState?.hasError ?? false;

  void dispose() => focusNode.dispose();
}

class _ExercisePicker extends ConsumerWidget {
  const _ExercisePicker({required this.excludedIds});

  final Set<String> excludedIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Añadir ejercicio',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: exercisesAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (_, __) => const Center(
                    child: Text('No se pudieron cargar los ejercicios')),
                data: (exercises) {
                  final available = exercises
                      .where((exercise) => !excludedIds.contains(exercise.id))
                      .toList();
                  if (available.isEmpty) {
                    return const Center(
                        child: Text('No hay más ejercicios disponibles'));
                  }
                  return ListView.separated(
                    itemCount: available.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final exercise = available[index];
                      return ListTile(
                        leading: const Icon(Icons.fitness_center),
                        title: Text(exercise.name),
                        trailing: const Icon(Icons.add),
                        onTap: () => Navigator.pop(context, exercise),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
