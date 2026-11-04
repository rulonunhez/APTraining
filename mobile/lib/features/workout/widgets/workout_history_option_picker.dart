import 'package:flutter/material.dart';

import '../models/workout_history_filter.dart';

/// Bottom sheet multi-selección de opciones del filtro del historial
/// (entrenos o ejercicios), con buscador. La selección se aplica en vivo
/// a través de [onChanged].
class WorkoutHistoryOptionPicker extends StatefulWidget {
  const WorkoutHistoryOptionPicker({
    super.key,
    required this.title,
    required this.searchHint,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String searchHint;
  final IconData icon;
  final List<WorkoutHistoryFilterOption> options;
  final List<WorkoutHistoryFilterOption> selected;
  final ValueChanged<List<WorkoutHistoryFilterOption>> onChanged;

  @override
  State<WorkoutHistoryOptionPicker> createState() =>
      _WorkoutHistoryOptionPickerState();
}

class _WorkoutHistoryOptionPickerState
    extends State<WorkoutHistoryOptionPicker> {
  String _query = '';
  late List<WorkoutHistoryFilterOption> _selected = List.of(widget.selected);

  bool _isSelected(WorkoutHistoryFilterOption option) =>
      _selected.any((item) => item.id == option.id);

  void _toggle(WorkoutHistoryFilterOption option) {
    setState(() {
      if (_isSelected(option)) {
        _selected.removeWhere((item) => item.id == option.id);
      } else {
        _selected.add(option);
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
    final filtered = widget.options
        .where((option) => option.name.toLowerCase().contains(_query))
        .toList();

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
                      widget.title,
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
                  hintText: widget.searchHint,
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
              child: filtered.isEmpty
                  ? const Center(child: Text('Sin resultados'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        return CheckboxListTile(
                          value: _isSelected(option),
                          onChanged: (_) => _toggle(option),
                          secondary: Icon(widget.icon),
                          title: Text(option.name),
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
