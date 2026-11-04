import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_loader.dart';
import '../models/exercise_catalogs.dart';
import '../providers/catalogs_provider.dart';

/// Chip de filtro por grupos musculares. Abre [MuscleGroupFilterPicker] y
/// permite quitar la selección con su icono de cierre.
class MuscleGroupFilterChip extends StatelessWidget {
  const MuscleGroupFilterChip({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final List<CatalogItem> selected;
  final ValueChanged<List<CatalogItem>> onChanged;

  /// Deshabilitado mientras no estén cargados los datos necesarios para
  /// cruzar grupos musculares con los ejercicios.
  final bool enabled;

  String get _label {
    if (selected.isEmpty) return 'Grupo muscular';
    if (selected.length == 1) return selected.first.name;
    return '${selected.length} grupos';
  }

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      showCheckmark: false,
      avatar: const Icon(Icons.accessibility_new, size: 18),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(_label, overflow: TextOverflow.ellipsis),
      ),
      selected: selected.isNotEmpty,
      onSelected: enabled
          ? (_) => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => MuscleGroupFilterPicker(
                  selected: selected,
                  onChanged: onChanged,
                ),
              )
          : null,
      onDeleted:
          selected.isNotEmpty ? () => onChanged(const <CatalogItem>[]) : null,
    );
  }
}

/// Bottom sheet multi-selección de grupos musculares del catálogo.
/// La selección se aplica en vivo a través de [onChanged].
class MuscleGroupFilterPicker extends ConsumerStatefulWidget {
  const MuscleGroupFilterPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final List<CatalogItem> selected;
  final ValueChanged<List<CatalogItem>> onChanged;

  @override
  ConsumerState<MuscleGroupFilterPicker> createState() =>
      _MuscleGroupFilterPickerState();
}

class _MuscleGroupFilterPickerState
    extends ConsumerState<MuscleGroupFilterPicker> {
  late List<CatalogItem> _selected = List.of(widget.selected);

  bool _isSelected(CatalogItem group) =>
      _selected.any((item) => item.id == group.id);

  void _toggle(CatalogItem group, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(group);
      } else {
        _selected.removeWhere((item) => item.id == group.id);
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
    final catalogsAsync = ref.watch(catalogsProvider);
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtrar por grupo muscular',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Se mostrarán entrenamientos con al menos un ejercicio de '
                'cada grupo seleccionado.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: catalogsAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (_, __) => const Center(
                  child: Text('No se pudieron cargar los grupos musculares'),
                ),
                data: (catalogs) {
                  if (catalogs.muscleGroups.isEmpty) {
                    return const Center(
                      child: Text('No hay grupos musculares disponibles'),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final group in catalogs.muscleGroups)
                          FilterChip(
                            label: Text(group.name),
                            selected: _isSelected(group),
                            onSelected: (selected) =>
                                _toggle(group, selected),
                          ),
                      ],
                    ),
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
