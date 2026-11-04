import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart';
import '../../workout/models/training.dart';
import '../utils/training_plan_filter.dart';

/// Barra de filtros de la vista "Planes": selector múltiple de entrenamientos,
/// estado de vigencia y "Limpiar" (solo resetea entrenamientos y estado).
class TrainingPlanFilterBar extends StatelessWidget {
  const TrainingPlanFilterBar({
    super.key,
    required this.trainings,
    required this.selectedTrainings,
    required this.onTrainingsChanged,
    required this.status,
    required this.onStatusChanged,
    required this.onClear,
    this.trainingsEnabled = true,
  });

  /// null mientras los entrenamientos no están cargados.
  final List<Training>? trainings;
  final List<Training> selectedTrainings;
  final ValueChanged<List<Training>> onTrainingsChanged;
  final TrainingPlanStatus? status;
  final ValueChanged<TrainingPlanStatus?> onStatusChanged;
  final VoidCallback onClear;
  final bool trainingsEnabled;

  bool get _hasActiveFilters => selectedTrainings.isNotEmpty || status != null;

  String get _trainingLabel {
    if (selectedTrainings.isEmpty) return 'Entreno';
    if (selectedTrainings.length == 1) return selectedTrainings.first.name;
    return '${selectedTrainings.length} entrenos';
  }

  void _pickTrainings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TrainingFilterPicker(
        trainings: trainings,
        selected: selectedTrainings,
        onChanged: onTrainingsChanged,
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
            avatar: const Icon(Icons.fitness_center, size: 18),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(_trainingLabel, overflow: TextOverflow.ellipsis),
            ),
            selected: selectedTrainings.isNotEmpty,
            onSelected: trainingsEnabled
                ? (_) => _pickTrainings(context)
                : null,
            onDeleted: selectedTrainings.isNotEmpty
                ? () => onTrainingsChanged(const <Training>[])
                : null,
          ),
          const SizedBox(width: 8),
          PopupMenuButton<TrainingPlanStatus?>(
            tooltip: 'Estado',
            initialValue: status,
            onSelected: onStatusChanged,
            itemBuilder: (_) => [
              const PopupMenuItem<TrainingPlanStatus?>(
                value: null,
                child: Text('Todos los estados'),
              ),
              for (final value in TrainingPlanStatus.values)
                PopupMenuItem<TrainingPlanStatus?>(
                  value: value,
                  child: Text(value.label),
                ),
            ],
            child: Chip(
              avatar: const Icon(Icons.flag_outlined, size: 18),
              label: Text(status?.label ?? 'Estado'),
              backgroundColor: status != null
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : null,
            ),
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

/// Bottom sheet multi-selección de entrenamientos. La selección se aplica
/// en vivo a través de [onChanged].
class _TrainingFilterPicker extends StatefulWidget {
  const _TrainingFilterPicker({
    required this.trainings,
    required this.selected,
    required this.onChanged,
  });

  final List<Training>? trainings;
  final List<Training> selected;
  final ValueChanged<List<Training>> onChanged;

  @override
  State<_TrainingFilterPicker> createState() => _TrainingFilterPickerState();
}

class _TrainingFilterPickerState extends State<_TrainingFilterPicker> {
  late List<Training> _selected = List.of(widget.selected);

  bool _isSelected(Training training) =>
      _selected.any((item) => item.id == training.id);

  void _toggle(Training training) {
    setState(() {
      if (_isSelected(training)) {
        _selected.removeWhere((item) => item.id == training.id);
      } else {
        _selected.add(training);
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
    final theme = Theme.of(context);
    final trainings = widget.trainings;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Planes con entrenos',
                      style: theme.textTheme.titleLarge,
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
            Expanded(
              child: trainings == null
                  ? const Center(child: AppLoader())
                  : trainings.isEmpty
                      ? const Center(child: Text('No hay entrenos creados'))
                      : ListView(
                          children: [
                            for (final training in trainings)
                              CheckboxListTile(
                                value: _isSelected(training),
                                title: Text(training.name),
                                onChanged: (_) => _toggle(training),
                              ),
                          ],
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
