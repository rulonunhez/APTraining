import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_loader.dart';
import '../../exercise/providers/exercises_provider.dart';
import '../models/training.dart';
import '../models/workout_history_entry.dart';
import '../models/workout_step.dart';
import '../providers/workout_history_provider.dart';
import '../providers/workout_rest_settings_provider.dart';
import '../providers/trainings_provider.dart';
import '../utils/workout_progress_controller.dart';
import '../utils/workout_steps_loader.dart';
import '../utils/workout_video_pool.dart';
import '../widgets/workout_pager.dart';
import 'workout_sets_editor.dart';
import 'workout_values_editor.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({
    super.key,
    required this.trainingId,
    this.initialTraining,
  });

  final String trainingId;
  final Training? initialTraining;

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen>
    with WidgetsBindingObserver {
  static const _preloadTimeout = Duration(seconds: 15);

  Training? _training;
  List<WorkoutStep> _steps = const [];
  WorkoutVideoPool? _pool;
  WorkoutProgressController? _progress;
  int _currentPage = 0;
  bool _loading = true;
  bool _allowPop = false;
  bool _confirmingExit = false;
  bool _isCompleted = false;
  bool _isEditingValues = false;
  bool _isLoggingSets = false;
  bool _isSavingHistory = false;
  bool _isUpdatingTemplate = false;
  bool _historySaved = false;
  bool _templateUpdateRequested = false;
  bool _templateUpdated = false;
  String? _loadError;
  String? _historySaveError;
  String? _templateUpdateError;
  Training? _pendingHistoryTraining;
  // Valores tal y como se editaron antes de registrar series: es lo único que
  // debe llegar a la plantilla, sin los ajustes de series de "solo hoy".
  Training? _templateSnapshot;
  List<List<WorkoutHistorySet>>? _pendingSetLogs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _training = widget.initialTraining;
    _loadTraining();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _pool?.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pool?.dispose();
    _progress?.dispose();
    super.dispose();
  }

  // Carga el entreno y deja listos los datos de todos los ejercicios y el
  // vídeo del primero antes de mostrar la sesión.
  Future<void> _loadTraining() async {
    if (_loadError != null) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final training = _training ??
          await ref
              .read(trainingsProvider.notifier)
              .getTraining(widget.trainingId);
      final steps = await loadWorkoutSteps(
        training,
        ref.read(exerciseRemoteDataSourceProvider),
      );
      if (!mounted) return;

      final pool = WorkoutVideoPool(steps: steps);
      await pool.setActive(0).timeout(_preloadTimeout, onTimeout: () {});
      if (!mounted) {
        pool.dispose();
        return;
      }

      _pool?.dispose();
      _progress?.dispose();
      setState(() {
        _training = training;
        _steps = steps;
        _pool = pool;
        _currentPage = 0;
        _progress = WorkoutProgressController(
          steps: steps,
          settings: ref.read(workoutRestSettingsProvider),
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudo cargar el entrenamiento';
      });
    }
  }

  Future<void> _confirmExit() async {
    if (_confirmingExit) return;
    _confirmingExit = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Salir del entrenamiento'),
        content: const Text('Volverás a la lista de Workout.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    _confirmingExit = false;

    if (shouldExit == true && mounted) {
      _leaveSession();
    }
  }

  void _leaveSession() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  Future<void> _beginRecordFlow() async {
    if (_isSavingHistory || _isUpdatingTemplate || _historySaved) return;
    if (_pendingHistoryTraining != null && _pendingSetLogs != null) {
      await _savePendingHistory();
      return;
    }

    final shouldEdit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modificar valores'),
        content: const Text(
          '¿Quieres ajustar los valores de los ejercicios para esta actividad?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Mantener actuales'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Modificar'),
          ),
        ],
      ),
    );
    if (!mounted || shouldEdit == null) return;

    if (!shouldEdit) {
      _pendingHistoryTraining = _training;
      _templateUpdateRequested = false;
      setState(() => _isLoggingSets = true);
      return;
    }

    setState(() => _isEditingValues = true);
  }

  Future<void> _saveEditedValues(Training training) async {
    setState(() {
      _training = training;
      _pendingHistoryTraining = training;
      _templateSnapshot = training;
      _isEditingValues = false;
    });

    // Solo el propietario puede guardar los valores en la plantilla
    if (!training.createdByMe) {
      _templateUpdateRequested = false;
      setState(() => _isLoggingSets = true);
      return;
    }

    final shouldUpdateTemplate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Actualizar próximos entrenamientos'),
        content: const Text(
          '¿Quieres guardar estos valores también en la plantilla?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Solo esta actividad'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Actualizar plantilla'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    _templateUpdateRequested = shouldUpdateTemplate == true;
    if (!mounted) return;
    setState(() => _isLoggingSets = true);
  }

  Future<void> _saveSetLogs(
    List<List<WorkoutHistorySet>> setLogs, {
    required List<TrainingExercise> exercises,
  }) async {
    final base = _pendingHistoryTraining ?? _training;
    if (base != null) {
      // El historial solo registra los ejercicios que el usuario mantuvo
      _pendingHistoryTraining = Training(
        id: base.id,
        name: base.name,
        description: base.description,
        exercises: exercises,
        createdByMe: base.createdByMe,
      );
    }
    setState(() {
      _pendingSetLogs = setLogs;
      _isLoggingSets = false;
    });
    await _savePendingHistory();
  }

  void _closeOverlay() {
    setState(() {
      _isEditingValues = false;
      _isLoggingSets = false;
    });
  }

  Future<void> _savePendingHistory() async {
    final snapshot = _pendingHistoryTraining;
    if (_isSavingHistory || _historySaved || snapshot == null) return;
    setState(() {
      _isSavingHistory = true;
      _historySaveError = null;
    });

    try {
      await ref.read(workoutHistoryRepositoryProvider).recordActivity(
            WorkoutHistoryEntry.fromTraining(
              snapshot,
              setsByExercise: _pendingSetLogs ?? const [],
            ),
          );
      if (!mounted) return;
      setState(() {
        _isSavingHistory = false;
        _historySaved = true;
      });
      if (_templateUpdateRequested) await _updateTemplate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSavingHistory = false;
        _historySaveError = 'No se pudo guardar la actividad';
      });
    }
  }

  Future<void> _updateTemplate() async {
    // Se actualiza con los valores editados, no con el recorte de series
    // que el usuario hizo solo para esta actividad.
    final snapshot = _templateSnapshot;
    final trainingId = snapshot?.id;
    if (snapshot == null ||
        trainingId == null ||
        _isUpdatingTemplate ||
        _templateUpdated) {
      return;
    }
    setState(() {
      _isUpdatingTemplate = true;
      _templateUpdateError = null;
    });

    try {
      await ref
          .read(trainingsProvider.notifier)
          .updateTraining(trainingId, snapshot);
      if (!mounted) return;
      setState(() {
        _isUpdatingTemplate = false;
        _templateUpdated = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isUpdatingTemplate = false;
        _templateUpdateError =
            'La actividad se guardó, pero no se pudo actualizar la plantilla';
      });
    }
  }

  Future<void> _retryTemplateUpdate() => _updateTemplate();

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: isLandscape
            ? null
            : AppBar(
                title: Text(
                  _isLoggingSets
                      ? 'Registrar series'
                      : _isEditingValues
                          ? 'Ajustar valores'
                          : _isCompleted
                              ? 'Resumen'
                              : _training?.name ?? 'Workout',
                ),
                leading: IconButton(
                  tooltip: 'Salir del entrenamiento',
                  onPressed: _isEditingValues || _isLoggingSets
                      ? _closeOverlay
                      : _confirmExit,
                  icon: Icon(
                    _isEditingValues || _isLoggingSets
                        ? Icons.arrow_back
                        : Icons.close,
                  ),
                ),
              ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_loading)
              const Center(child: AppLoader())
            else if (_loadError != null)
              Center(
                child: TextButton.icon(
                  onPressed: _loadTraining,
                  icon: const Icon(Icons.refresh),
                  label: Text(_loadError!),
                ),
              )
            else if (_isLoggingSets)
              WorkoutSetsEditor(
                training: _pendingHistoryTraining ?? _training!,
                onCancel: _closeOverlay,
                onSave: _saveSetLogs,
              )
            else if (_isEditingValues)
              WorkoutValuesEditor(
                training: _training!,
                onCancel: () => setState(() => _isEditingValues = false),
                onSave: _saveEditedValues,
              )
            else if (_isCompleted)
              _WorkoutCompletionSummary(
                training: _pendingHistoryTraining ?? _training!,
                onReview: () => setState(() => _isCompleted = false),
                onReturn: _leaveSession,
                onSave: _beginRecordFlow,
                onFinishWithoutSave: _leaveSession,
                onRetryTemplateUpdate: _retryTemplateUpdate,
                isSaving: _isSavingHistory,
                isUpdatingTemplate: _isUpdatingTemplate,
                isSaved: _historySaved,
                saveError: _historySaveError,
                templateUpdateError: _templateUpdateError,
                templateUpdateRequested: _templateUpdateRequested,
                templateUpdated: _templateUpdated,
              )
            else
              WorkoutPager(
                training: _training!,
                steps: _steps,
                pool: _pool!,
                progress: _progress!,
                initialPage: _currentPage,
                isLandscape: isLandscape,
                onPageChanged: (page) => _currentPage = page,
                onFinish: () => setState(() => _isCompleted = true),
              ),
            if (isLandscape)
              Positioned(
                top: 8,
                left: 8,
                child: SafeArea(
                  child: IconButton.filled(
                    tooltip: 'Salir del entrenamiento',
                    onPressed: _isEditingValues || _isLoggingSets
                        ? _closeOverlay
                        : _confirmExit,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutCompletionSummary extends StatelessWidget {
  const _WorkoutCompletionSummary({
    required this.training,
    required this.onReview,
    required this.onReturn,
    required this.onSave,
    required this.onFinishWithoutSave,
    required this.onRetryTemplateUpdate,
    required this.isSaving,
    required this.isUpdatingTemplate,
    required this.isSaved,
    required this.saveError,
    required this.templateUpdateError,
    required this.templateUpdateRequested,
    required this.templateUpdated,
  });

  final Training training;
  final VoidCallback onReview;
  final VoidCallback onReturn;
  final VoidCallback onSave;
  final VoidCallback onFinishWithoutSave;
  final VoidCallback onRetryTemplateUpdate;
  final bool isSaving;
  final bool isUpdatingTemplate;
  final bool isSaved;
  final String? saveError;
  final String? templateUpdateError;
  final bool templateUpdateRequested;
  final bool templateUpdated;

  @override
  Widget build(BuildContext context) {
    final totalSets = training.exercises.fold<int>(
      0,
      (total, exercise) => total + exercise.series,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Entrenamiento finalizado',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(training.name),
            const SizedBox(height: 4),
            Text('${training.exercises.length} ejercicios · $totalSets series'),
            const SizedBox(height: 12),
            if (isSaved)
              Text(
                templateUpdateRequested
                    ? templateUpdated
                        ? 'Actividad guardada y plantilla actualizada'
                        : isUpdatingTemplate
                            ? 'Actividad guardada; actualizando plantilla'
                            : 'Actividad guardada en el historial'
                    : 'Actividad guardada en el historial',
              )
            else ...[
              const Text('¿Quieres registrar esta actividad?'),
              if (saveError != null) ...[
                const SizedBox(height: 8),
                Text(
                  saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
            const SizedBox(height: 20),
            if (templateUpdateError != null) ...[
              Text(
                templateUpdateError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isUpdatingTemplate ? null : onRetryTemplateUpdate,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar actualización'),
              ),
              const SizedBox(height: 8),
            ],
            if (!isSaved)
              FilledButton.icon(
                onPressed: isSaving || isUpdatingTemplate ? null : onSave,
                icon: isSaving || isUpdatingTemplate
                    ? const SizedBox.square(
                        dimension: 18,
                        child: AppLoader(size: 18, color: Colors.white),
                      )
                    : const Icon(Icons.bookmark_add_outlined),
                label: const Text('Guardar actividad'),
              ),
            if (!isSaved) const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: isSaving || isUpdatingTemplate ? null : onReview,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Revisar entrenamiento'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: isSaving || isUpdatingTemplate ? null : onReturn,
              icon: Icon(isSaved ? Icons.arrow_back : Icons.close),
              label:
                  Text(isSaved ? 'Volver a Workout' : 'Terminar sin guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
