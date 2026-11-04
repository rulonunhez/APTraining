import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_loader.dart';
import '../../users/models/app_user.dart';
import '../../users/providers/users_providers.dart';
import '../../users/screens/user_picker_screen.dart';
import '../models/workout_history_entry.dart';
import '../models/workout_history_filter.dart';
import '../providers/workout_history_provider.dart';
import '../utils/date_format.dart';
import '../widgets/workout_history_option_picker.dart';

/// Historial de entrenos con filtros de fecha, entreno y ejercicio
/// (estos dos últimos conviven con lógica OR). En modo [otherUsersMode],
/// disponible para entrenadores y admin, es obligatorio elegir un único
/// usuario antes de buscar.
class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({super.key, this.otherUsersMode = false});

  final bool otherUsersMode;

  @override
  ConsumerState<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  late final DateTime _initialTo = DateTime.now();
  // Por defecto se acota al último año para tener un tope
  late DateTime _from =
      DateTime(_initialTo.year - 1, _initialTo.month, _initialTo.day);
  late DateTime _to = _initialTo;

  List<WorkoutHistoryFilterOption> _selectedTrainings = const [];
  List<WorkoutHistoryFilterOption> _selectedExercises = const [];
  AppUser? _selectedUser;

  List<WorkoutHistoryEntry>? _results;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if (!widget.otherUsersMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  bool get _canSearch => !widget.otherUsersMode || _selectedUser != null;

  Future<void> _search() async {
    if (!_canSearch) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      // Las fechas cubren el día completo en hora local
      final from = DateTime(_from.year, _from.month, _from.day);
      final to = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);
      final results = await ref
          .read(workoutHistoryRepositoryProvider)
          .searchWorkoutHistory(
            from: from,
            to: to,
            trainingIds: [for (final training in _selectedTrainings) training.id],
            exerciseIds: [for (final exercise in _selectedExercises) exercise.id],
            userId: _selectedUser?.id,
          );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (selected != null) {
      setState(() {
        _from = selected.start;
        _to = selected.end;
      });
    }
  }

  Future<void> _pickUser() async {
    // El historial propio ya tiene su pantalla: no se ofrece aquí.
    final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
    final selected = await Navigator.push<List<AppUser>>(
      context,
      MaterialPageRoute(
        builder: (_) => UserPickerScreen(
          initialSelected: [if (_selectedUser != null) _selectedUser!],
          excludedUserIds: {if (currentUserId != null) currentUserId},
          title: 'Seleccionar usuario',
          singleSelection: true,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedUser = selected.isEmpty ? null : selected.first;
      // Al cambiar de usuario se resetean los filtros derivados de su historial
      _selectedTrainings = const [];
      _selectedExercises = const [];
      _results = null;
    });
    if (_selectedUser != null) _search();
  }

  void _pickOptions({
    required String title,
    required String searchHint,
    required IconData icon,
    required List<WorkoutHistoryFilterOption> options,
    required List<WorkoutHistoryFilterOption> selected,
    required ValueChanged<List<WorkoutHistoryFilterOption>> onChanged,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WorkoutHistoryOptionPicker(
        title: title,
        searchHint: searchHint,
        icon: icon,
        options: options,
        selected: selected,
        onChanged: onChanged,
      ),
    );
  }

  void _clearFilters() => setState(() {
        _from = DateTime(_initialTo.year - 1, _initialTo.month, _initialTo.day);
        _to = _initialTo;
        _selectedTrainings = const [];
        _selectedExercises = const [];
      });

  bool get _hasActiveFilters =>
      _selectedTrainings.isNotEmpty ||
      _selectedExercises.isNotEmpty ||
      _from !=
          DateTime(_initialTo.year - 1, _initialTo.month, _initialTo.day) ||
      _to != _initialTo;

  String _selectionLabel(List<WorkoutHistoryFilterOption> selected,
      String singular, String plural) {
    if (selected.isEmpty) return singular;
    if (selected.length == 1) return selected.first.name;
    return '${selected.length} $plural';
  }

  @override
  Widget build(BuildContext context) {
    final optionsUserId = widget.otherUsersMode ? _selectedUser?.id : null;
    final optionsAsync = (widget.otherUsersMode && _selectedUser == null)
        ? const AsyncValue<WorkoutHistoryFilterOptions>.data(
            WorkoutHistoryFilterOptions(),
          )
        : ref.watch(workoutHistoryFilterOptionsProvider(optionsUserId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUsersMode
            ? 'Historial de usuarios'
            : 'Historial de entrenos'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _FilterSection(
              otherUsersMode: widget.otherUsersMode,
              selectedUser: _selectedUser,
              onPickUser: _pickUser,
              from: _from,
              to: _to,
              onPickDateRange: _pickDateRange,
              trainingLabel: _selectionLabel(
                  _selectedTrainings, 'Entreno', 'entrenos'),
              exerciseLabel: _selectionLabel(
                  _selectedExercises, 'Ejercicio', 'ejercicios'),
              onPickTrainings: optionsAsync.valueOrNull == null
                  ? null
                  : () => _pickOptions(
                        title: 'Filtrar por entreno',
                        searchHint: 'Buscar entreno...',
                        icon: Icons.fitness_center,
                        options: optionsAsync.valueOrNull?.trainings ??
                            const [],
                        selected: _selectedTrainings,
                        onChanged: (value) =>
                            setState(() => _selectedTrainings = value),
                      ),
              onPickExercises: optionsAsync.valueOrNull == null
                  ? null
                  : () => _pickOptions(
                        title: 'Filtrar por ejercicio',
                        searchHint: 'Buscar ejercicio...',
                        icon: Icons.sports_gymnastics,
                        options: optionsAsync.valueOrNull?.exercises ??
                            const [],
                        selected: _selectedExercises,
                        onChanged: (value) =>
                            setState(() => _selectedExercises = value),
                      ),
              hasActiveFilters: _hasActiveFilters,
              onClear: _clearFilters,
              canSearch: _canSearch,
              loading: _loading,
              onSearch: _search,
            ),
            const Divider(height: 1),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (widget.otherUsersMode && _selectedUser == null) {
      return const _CenteredMessage(
        icon: Icons.person_search,
        message: 'Selecciona un usuario para ver su historial',
      );
    }
    if (_loading) {
      return const Center(child: AppLoader());
    }
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudo cargar el historial'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return const SizedBox.shrink();
    }
    if (results.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.history,
        message: 'No hay entrenos que coincidan con los filtros',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = results[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.fitness_center),
            title: Text(entry.trainingName),
            subtitle: Text(
              '${entry.completedAt == null ? '' : '${formatDateTime(entry.completedAt!.toLocal())} · '}'
              '${entry.exercises.length} ejercicios',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              '/profile/workout-history/detail',
              extra: entry,
            ),
          ),
        );
      },
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.otherUsersMode,
    required this.selectedUser,
    required this.onPickUser,
    required this.from,
    required this.to,
    required this.onPickDateRange,
    required this.trainingLabel,
    required this.exerciseLabel,
    required this.onPickTrainings,
    required this.onPickExercises,
    required this.hasActiveFilters,
    required this.onClear,
    required this.canSearch,
    required this.loading,
    required this.onSearch,
  });

  final bool otherUsersMode;
  final AppUser? selectedUser;
  final VoidCallback onPickUser;
  final DateTime from;
  final DateTime to;
  final VoidCallback onPickDateRange;
  final String trainingLabel;
  final String exerciseLabel;
  final VoidCallback? onPickTrainings;
  final VoidCallback? onPickExercises;
  final bool hasActiveFilters;
  final VoidCallback onClear;
  final bool canSearch;
  final bool loading;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final pickTrainings = onPickTrainings;
    final pickExercises = onPickExercises;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (otherUsersMode) ...[
            OutlinedButton.icon(
              onPressed: onPickUser,
              icon: const Icon(Icons.person_outline),
              label: Text(
                selectedUser == null
                    ? 'Seleccionar usuario *'
                    : selectedUser!.username,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                showCheckmark: false,
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text('${formatDate(from)} - ${formatDate(to)}'),
                selected: true,
                onSelected: (_) => onPickDateRange(),
              ),
              FilterChip(
                showCheckmark: false,
                avatar: const Icon(Icons.fitness_center, size: 18),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(trainingLabel, overflow: TextOverflow.ellipsis),
                ),
                selected: trainingLabel != 'Entreno',
                onSelected:
                    pickTrainings == null ? null : (_) => pickTrainings(),
              ),
              FilterChip(
                showCheckmark: false,
                avatar: const Icon(Icons.sports_gymnastics, size: 18),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(exerciseLabel, overflow: TextOverflow.ellipsis),
                ),
                selected: exerciseLabel != 'Ejercicio',
                onSelected:
                    pickExercises == null ? null : (_) => pickExercises(),
              ),
              if (hasActiveFilters)
                TextButton(
                  onPressed: onClear,
                  child: const Text('Limpiar'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: canSearch && !loading ? onSearch : null,
            icon: const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
