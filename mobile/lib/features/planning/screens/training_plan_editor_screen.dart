import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ap_training/features/users/models/app_user.dart';
import 'package:ap_training/features/users/models/user_group.dart';
import 'package:ap_training/features/users/providers/groups_provider.dart';
import 'package:ap_training/features/users/providers/users_providers.dart';
import 'package:ap_training/features/users/screens/user_picker_screen.dart';
import 'package:ap_training/features/workout/models/training.dart';
import 'package:ap_training/features/workout/providers/trainings_provider.dart';
import 'package:ap_training/core/widgets/app_loader.dart';

import '../data/training_plan_remote_data_source.dart';
import '../models/training_plan.dart';
import '../providers/training_plans_provider.dart';
import '../widgets/training_date_calendar.dart';

class TrainingPlanEditorScreen extends ConsumerStatefulWidget {
  const TrainingPlanEditorScreen({super.key, this.planId});

  final String? planId;

  @override
  ConsumerState<TrainingPlanEditorScreen> createState() =>
      _TrainingPlanEditorScreenState();
}

class _TrainingPlanEditorScreenState
    extends ConsumerState<TrainingPlanEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocusNode = FocusNode();
  final _nameController = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  bool _hasValidityPeriod = true;
  TrainingPlanMode _mode = TrainingPlanMode.weekly;
  List<TrainingPlanWorkout> _workouts = const [];
  List<AppUser> _assignedUsers = const [];
  String? _expandedTrainingId;
  bool _loading = false;
  bool _saving = false;
  bool _invalidDateRange = false;
  bool _readOnly = false;
  String? _assignedByUsername;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _startDate = DateUtils.dateOnly(DateTime.now());
    _endDate = _startDate.add(const Duration(days: 28));
    if (widget.planId != null) {
      _loading = true;
      _loadPlan();
    }
  }

  Future<void> _loadPlan() async {
    try {
      final plan = await ref
          .read(trainingPlansProvider.notifier)
          .getTrainingPlan(widget.planId!);
      if (!mounted) return;
      final defaultStartDate = DateUtils.dateOnly(DateTime.now());
      final startDate = plan.startDate ?? defaultStartDate;
      final endDate = plan.endDate ?? startDate.add(const Duration(days: 28));
      setState(() {
        _nameController.text = plan.name;
        _mode = plan.mode;
        _hasValidityPeriod = plan.startDate != null || plan.endDate != null;
        _startDate = DateUtils.dateOnly(startDate);
        _endDate = DateUtils.dateOnly(endDate);
        _workouts = plan.workouts;
        _readOnly = !plan.createdByMe;
        _assignedByUsername = plan.assignedByUsername;
        _assignedUsers = plan.assignedUsers;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'No se pudo cargar la planificación';
        });
      }
    }
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;

    setState(() {
      if (isStartDate) {
        _startDate = DateUtils.dateOnly(selected);
      } else {
        _endDate = DateUtils.dateOnly(selected);
      }
      _invalidDateRange = _endDate.isBefore(_startDate);
      if (!_invalidDateRange) _pruneDatesOutsideRange();
    });
  }

  void _pruneDatesOutsideRange() {
    final first = DateUtils.dateOnly(_startDate);
    final last = DateUtils.dateOnly(_endDate);
    _workouts = [
      for (final workout in _workouts)
        workout.copyWith(
          dates: workout.dates
              .where((item) =>
                  !item.date.isBefore(first) && !item.date.isAfter(last))
              .toList(),
        ),
    ];
  }

  void _changeMode(Set<TrainingPlanMode> selection) {
    final mode = selection.first;
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      if (mode == TrainingPlanMode.free) {
        _hasValidityPeriod = true;
      }
      _invalidDateRange = _hasValidityPeriod && _endDate.isBefore(_startDate);
      _workouts = [
        for (final workout in _workouts)
          workout.copyWith(schedules: const [], dates: const []),
      ];
    });
  }

  Future<void> _addTraining() async {
    final selected = await showModalBottomSheet<Training>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TrainingPicker(
        excludedIds: _workouts.map((workout) => workout.trainingId).toSet(),
      ),
    );
    if (selected == null || selected.id == null || !mounted) return;

    final trainingId = selected.id!;
    setState(() {
      _expandedTrainingId = trainingId;
      _workouts = [
        ..._workouts,
        TrainingPlanWorkout(
          trainingId: trainingId,
          trainingName: selected.name,
          orderIndex: _workouts.length,
          schedules: const [],
        ),
      ];
    });
  }

  void _toggleTraining(String trainingId) {
    setState(() {
      _expandedTrainingId =
          _expandedTrainingId == trainingId ? null : trainingId;
    });
  }

  void _removeTraining(String trainingId) {
    setState(() {
      _workouts = _workouts
          .where((workout) => workout.trainingId != trainingId)
          .toList();
      _normalizeWorkoutOrder();
      if (_expandedTrainingId == trainingId) _expandedTrainingId = null;
    });
  }

  void _reorderWorkouts(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final reordered = [..._workouts];
      final workout = reordered.removeAt(oldIndex);
      reordered.insert(newIndex, workout);
      _workouts = reordered;
      _normalizeWorkoutOrder();
    });
  }

  void _normalizeWorkoutOrder() {
    _workouts = [
      for (var index = 0; index < _workouts.length; index++)
        _workouts[index].copyWith(orderIndex: index),
    ];
  }

  void _toggleDay(
    String trainingId,
    TrainingPlanDay day,
    bool selected,
  ) {
    final workout = _workouts.firstWhere(
      (item) => item.trainingId == trainingId,
    );
    final schedules = [...workout.schedules];
    if (selected) {
      schedules.add(TrainingPlanSchedule(dayOfWeek: day));
    } else {
      schedules.removeWhere((schedule) => schedule.dayOfWeek == day);
    }
    schedules.sort(
      (first, second) =>
          first.dayOfWeek.index.compareTo(second.dayOfWeek.index),
    );
    _replaceSchedules(workout, schedules);
  }

  Future<void> _editScheduleTime(
    TrainingPlanWorkout workout,
    TrainingPlanSchedule schedule,
  ) async {
    final slot = await _pickTimeSlot(
      startMinuteOfDay: schedule.startMinuteOfDay,
      endMinuteOfDay: schedule.endMinuteOfDay,
    );
    if (slot == null) return;

    _replaceSchedules(
      workout,
      workout.schedules
          .map(
            (item) => item.dayOfWeek == schedule.dayOfWeek
                ? TrainingPlanSchedule(
                    dayOfWeek: item.dayOfWeek,
                    startMinuteOfDay: slot.startMinuteOfDay,
                    endMinuteOfDay: slot.endMinuteOfDay,
                  )
                : item,
          )
          .toList(),
    );
  }

  Future<void> _editDateTime(
    TrainingPlanWorkout workout,
    TrainingPlanDate date,
  ) async {
    final slot = await _pickTimeSlot(
      startMinuteOfDay: date.startMinuteOfDay,
      endMinuteOfDay: date.endMinuteOfDay,
    );
    if (slot == null) return;

    _replaceDates(
      workout,
      workout.dates
          .map(
            (item) => DateUtils.isSameDay(item.date, date.date)
                ? TrainingPlanDate(
                    date: item.date,
                    startMinuteOfDay: slot.startMinuteOfDay,
                    endMinuteOfDay: slot.endMinuteOfDay,
                  )
                : item,
          )
          .toList(),
    );
  }

  Future<void> _applyTimeToAllDates(TrainingPlanWorkout workout) async {
    final slot = await _pickTimeSlot();
    if (slot == null) return;

    _replaceDates(
      workout,
      workout.dates
          .map(
            (item) => TrainingPlanDate(
              date: item.date,
              startMinuteOfDay: slot.startMinuteOfDay,
              endMinuteOfDay: slot.endMinuteOfDay,
            ),
          )
          .toList(),
    );
  }

  Future<void> _applyTimeToAllSchedules(TrainingPlanWorkout workout) async {
    final slot = await _pickTimeSlot();
    if (slot == null) return;

    _replaceSchedules(
      workout,
      workout.schedules
          .map(
            (item) => TrainingPlanSchedule(
              dayOfWeek: item.dayOfWeek,
              startMinuteOfDay: slot.startMinuteOfDay,
              endMinuteOfDay: slot.endMinuteOfDay,
            ),
          )
          .toList(),
    );
  }

  Future<TrainingPlanSlot?> _pickTimeSlot({
    int? startMinuteOfDay,
    int? endMinuteOfDay,
  }) async {
    final startTime = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromMinute(startMinuteOfDay ?? 19 * 60),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Hora de inicio',
    );
    if (startTime == null || !mounted) return null;

    final startMinute = startTime.hour * 60 + startTime.minute;
    final defaultEndMinute = startMinute + 60;
    final defaultEnd = endMinuteOfDay ??
        (defaultEndMinute <= 23 * 60 + 59 ? defaultEndMinute : 23 * 60 + 59);
    final endTime = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromMinute(defaultEnd),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Hora de fin',
    );
    if (endTime == null || !mounted) return null;

    final endMinute = endTime.hour * 60 + endTime.minute;
    if (endMinute <= startMinute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La hora de fin debe ser posterior')),
      );
      return null;
    }

    return (startMinuteOfDay: startMinute, endMinuteOfDay: endMinute);
  }

  void _clearScheduleTime(
    TrainingPlanWorkout workout,
    TrainingPlanSchedule schedule,
  ) {
    _replaceSchedules(
      workout,
      workout.schedules
          .map(
            (item) => item.dayOfWeek == schedule.dayOfWeek
                ? TrainingPlanSchedule(dayOfWeek: item.dayOfWeek)
                : item,
          )
          .toList(),
    );
  }

  void _clearDateTime(TrainingPlanWorkout workout, TrainingPlanDate date) {
    _replaceDates(
      workout,
      workout.dates
          .map(
            (item) => DateUtils.isSameDay(item.date, date.date)
                ? TrainingPlanDate(date: item.date)
                : item,
          )
          .toList(),
    );
  }

  void _replaceSchedules(
    TrainingPlanWorkout workout,
    List<TrainingPlanSchedule> schedules,
  ) {
    _replaceWorkout(workout.copyWith(schedules: schedules));
  }

  void _replaceDates(
      TrainingPlanWorkout workout, List<TrainingPlanDate> dates) {
    _replaceWorkout(workout.copyWith(dates: dates));
  }

  void _replaceWorkout(TrainingPlanWorkout updated) {
    setState(() {
      _workouts = _workouts
          .map((item) => item.trainingId == updated.trainingId ? updated : item)
          .toList();
    });
  }

  void _toggleDate(String trainingId, DateTime date) {
    final workout = _workouts.firstWhere(
      (item) => item.trainingId == trainingId,
    );
    final day = DateUtils.dateOnly(date);
    final isSelected = workout.dates.any(
      (item) => DateUtils.isSameDay(item.date, day),
    );
    final dates = isSelected
        ? workout.dates
            .where((item) => !DateUtils.isSameDay(item.date, day))
            .toList()
        : ([...workout.dates, TrainingPlanDate(date: day)]
          ..sort((first, second) => first.date.compareTo(second.date)));
    _replaceDates(workout, dates);
  }

  /// El creador nunca se asigna a sí mismo: sus planes creados siempre se
  /// muestran. Los usuarios ya asignados tampoco se ofrecen de nuevo.
  Future<void> _pickAssignedUsers() async {
    final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
    final selected = await Navigator.of(context).push<List<AppUser>>(
      MaterialPageRoute(
        builder: (_) => UserPickerScreen(
          excludedUserIds: {
            if (currentUserId != null) currentUserId,
            for (final user in _assignedUsers) user.id,
          },
          title: 'Añadir usuarios',
        ),
      ),
    );
    if (selected != null && selected.isNotEmpty) {
      setState(() => _addAssignedUsers(selected));
    }
  }

  /// Rellena la lista de usuarios asignados con los miembros del grupo
  /// elegido. El grupo solo es un atajo visual: se asignan sus miembros.
  void _addGroupMembers(UserGroup group) {
    final before = _assignedUsers.length;
    setState(() => _addAssignedUsers(group.members));
    final added = _assignedUsers.length - before;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added == 0
              ? 'Los miembros de "${group.name}" ya estaban asignados'
              : 'Se añadieron $added usuario(s) de "${group.name}"',
        ),
      ),
    );
  }

  void _addAssignedUsers(List<AppUser> users) {
    final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
    final knownIds = _assignedUsers.map((user) => user.id).toSet();
    _assignedUsers = [
      ..._assignedUsers,
      for (final user in users)
        if (user.id != currentUserId && knownIds.add(user.id)) user,
    ];
  }

  Future<void> _save() async {
    if (_readOnly) return;
    if (!_formKey.currentState!.validate()) {
      await _focusNameFieldIfInvalid();
      return;
    }
    if (_hasValidityPeriod && _endDate.isBefore(_startDate)) {
      setState(() => _invalidDateRange = true);
      return;
    }
    final workoutWithoutDays = _workouts.where((workout) {
      return _mode == TrainingPlanMode.free
          ? workout.dates.isEmpty
          : workout.schedules.isEmpty;
    }).firstOrNull;
    if (workoutWithoutDays != null) {
      setState(() => _expandedTrainingId = workoutWithoutDays.trainingId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mode == TrainingPlanMode.free
              ? 'Selecciona al menos una fecha para cada entrenamiento'
              : 'Selecciona al menos un día para cada entrenamiento'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final plan = TrainingPlan(
      id: widget.planId,
      name: _nameController.text.trim(),
      mode: _mode,
      startDate: _hasValidityPeriod ? _startDate : null,
      endDate: _hasValidityPeriod ? _endDate : null,
      workouts: _workouts,
      assignedUserIds: _assignedUsers.map((user) => user.id).toList(),
      // Los grupos son solo un atajo visual para rellenar usuarios: la
      // asignación siempre se materializa como usuarios individuales.
      assignedGroupIds: const [],
    );

    try {
      if (widget.planId == null) {
        await ref.read(trainingPlansProvider.notifier).createTrainingPlan(plan);
      } else {
        await ref
            .read(trainingPlansProvider.notifier)
            .updateTrainingPlan(widget.planId!, plan);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_saveErrorMessage(error))),
        );
      }
    }
  }

  /// Si el nombre no es válido, pone el foco en él y lo hace visible para
  /// que el usuario vea qué falta sin tener que buscarlo.
  Future<void> _focusNameFieldIfInvalid() async {
    final fieldContext = _nameFocusNode.context;
    if (fieldContext == null || !fieldContext.mounted) return;
    final hasError = fieldContext
            .findAncestorStateOfType<FormFieldState<String>>()
            ?.hasError ??
        false;
    if (!hasError) return;
    _nameFocusNode.requestFocus();
    await Scrollable.ensureVisible(
      fieldContext,
      alignment: 0.25,
      duration: const Duration(milliseconds: 250),
    );
  }

  String _saveErrorMessage(Object error) {
    if (error is TrainingPlanApiException && error.message != null) {
      return error.message!;
    }
    return 'No se pudo guardar la planificación';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.planId != null;
    final canAssign =
        ref.watch(currentUserProvider).valueOrNull?.canManageGroups ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(_readOnly
            ? 'Planificación asignada'
            : isEditing
                ? 'Editar planificación'
                : 'Nueva planificación'),
        actions: [
          if (!_readOnly)
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
                      if (_readOnly)
                        Card(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: ListTile(
                            leading: const Icon(Icons.lock_outline),
                            title:
                                const Text('Plan asignado por tu entrenador'),
                            subtitle: Text(
                              'Asignado por ${_assignedByUsername ?? 'tu entrenador'}. '
                              'Solo lectura.',
                            ),
                          ),
                        ),
                      if (_readOnly) const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('trainingPlanName'),
                        focusNode: _nameFocusNode,
                        controller: _nameController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 255,
                        readOnly: _readOnly,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'El nombre es obligatorio'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      Text('Tipo de planificación',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<TrainingPlanMode>(
                          segments: const [
                            ButtonSegment(
                              value: TrainingPlanMode.weekly,
                              label: Text('Semanal'),
                              icon: Icon(Icons.repeat),
                            ),
                            ButtonSegment(
                              value: TrainingPlanMode.free,
                              label: Text('Libre'),
                              icon: Icon(Icons.calendar_month),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: isEditing || _saving || _readOnly
                              ? null
                              : _changeMode,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _mode == TrainingPlanMode.free
                              ? 'Elige los días concretos en el calendario.'
                              : 'Elige los días de la semana que se repiten cada semana.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Periodo de vigencia',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Limitar vigencia'),
                        subtitle: Text(_hasValidityPeriod
                            ? 'La planificación estará activa entre estas fechas.'
                            : 'La planificación estará activa sin límite de fechas.'),
                        value: _hasValidityPeriod,
                        onChanged: _saving ||
                                _readOnly ||
                                _mode == TrainingPlanMode.free
                            ? null
                            : (value) => setState(() {
                                  _hasValidityPeriod = value;
                                  _invalidDateRange =
                                      value && _endDate.isBefore(_startDate);
                                }),
                      ),
                      if (_hasValidityPeriod) ...[
                        _DateField(
                          label: 'Fecha de inicio',
                          date: _startDate,
                          onTap: _readOnly
                              ? () {}
                              : () => _selectDate(isStartDate: true),
                        ),
                        const SizedBox(height: 12),
                        _DateField(
                          label: 'Fecha de fin',
                          date: _endDate,
                          onTap: _readOnly
                              ? () {}
                              : () => _selectDate(isStartDate: false),
                        ),
                        if (_invalidDateRange) ...[
                          const SizedBox(height: 8),
                          Text(
                            'La fecha de fin no puede ser anterior a la de inicio',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Entrenamientos',
                                style: Theme.of(context).textTheme.titleLarge),
                          ),
                          Text('${_workouts.length}'),
                          const SizedBox(width: 8),
                          if (!_readOnly)
                            IconButton.filledTonal(
                              tooltip: 'Añadir entrenamiento',
                              onPressed: _saving ? null : _addTraining,
                              icon: const Icon(Icons.add),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_workouts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'Añade entrenamientos y selecciona sus días de trabajo.',
                          ),
                        )
                      else if (_readOnly)
                        for (final workout in _workouts)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.fitness_center),
                              title: Text(
                                workout.trainingName ?? 'Entrenamiento',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle:
                                  Text(_workoutScheduleSummary(workout, _mode)),
                            ),
                          )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _workouts.length,
                          onReorder: _reorderWorkouts,
                          itemBuilder: (context, index) =>
                              _buildWorkoutCard(_workouts[index], index),
                        ),
                      if (canAssign && !_readOnly) ...[
                        const SizedBox(height: 24),
                        _buildAssignmentSection(context),
                      ],
                      const SizedBox(height: 24),
                      if (!_readOnly)
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(isEditing
                              ? 'Guardar cambios'
                              : 'Crear planificación'),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAssignmentSection(BuildContext context) {
    final theme = Theme.of(context);
    final groups = ref.watch(groupsProvider).valueOrNull ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Asignar a usuarios', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'La planificación se asigna a usuarios concretos; tú siempre '
          'verás las que crees. Usa un grupo solo como atajo para rellenar '
          'la lista con sus miembros.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (groups.isNotEmpty) ...[
          _GroupFillField(
            groups: groups,
            enabled: !_saving,
            onSelected: _addGroupMembers,
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: Text('Usuarios asignados (${_assignedUsers.length})',
                  style: theme.textTheme.titleSmall),
            ),
            TextButton.icon(
              onPressed: _saving ? null : _pickAssignedUsers,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Añadir'),
            ),
          ],
        ),
        if (_assignedUsers.isEmpty)
          Text(
            'Sin usuarios asignados: la planificación solo la verás tú.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final user in _assignedUsers)
                InputChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(user.username),
                  onDeleted: _saving
                      ? null
                      : () => setState(() {
                            _assignedUsers = _assignedUsers
                                .where((item) => item.id != user.id)
                                .toList();
                          }),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildWorkoutCard(TrainingPlanWorkout workout, int index) {
    final isExpanded = _expandedTrainingId == workout.trainingId;

    return Card(
      key: ValueKey(workout.trainingId),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
            title: Text(
              workout.trainingName ?? 'Entrenamiento',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_workoutScheduleSummary(workout, _mode)),
            onTap: () => _toggleTraining(workout.trainingId),
            trailing: SizedBox(
              width: 88,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip:
                        'Quitar ${workout.trainingName ?? 'entrenamiento'}',
                    onPressed: _saving
                        ? null
                        : () => _removeTraining(workout.trainingId),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _mode == TrainingPlanMode.free
                    ? _buildFreeModeContent(workout)
                    : _buildWeeklyModeContent(workout),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildWeeklyModeContent(TrainingPlanWorkout workout) {
    final theme = Theme.of(context);
    return [
      Text('Días de trabajo', style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final day in TrainingPlanDay.values)
            Tooltip(
              message: _dayName(day),
              child: FilterChip(
                key: ValueKey('plan-day-${workout.trainingId}-${day.name}'),
                label: Text(_dayInitial(day)),
                selected: workout.schedules.any(
                  (schedule) => schedule.dayOfWeek == day,
                ),
                onSelected: _saving
                    ? null
                    : (selected) => _toggleDay(
                          workout.trainingId,
                          day,
                          selected,
                        ),
              ),
            ),
        ],
      ),
      if (workout.schedules.isNotEmpty) ...[
        const Divider(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: ValueKey('plan-apply-time-${workout.trainingId}'),
            onPressed: _saving ? null : () => _applyTimeToAllSchedules(workout),
            icon: const Icon(Icons.schedule),
            label: const Text('Aplicar la misma hora a todos'),
          ),
        ),
        const SizedBox(height: 4),
        for (final schedule in workout.schedules)
          _ScheduleTimeRow(
            key: ValueKey(
                'schedule-${workout.trainingId}-${schedule.dayOfWeek.name}'),
            label: _dayName(schedule.dayOfWeek),
            startMinuteOfDay: schedule.startMinuteOfDay,
            endMinuteOfDay: schedule.endMinuteOfDay,
            onSetTime: () => _editScheduleTime(workout, schedule),
            onClearTime: () => _clearScheduleTime(workout, schedule),
            enabled: !_saving,
          ),
      ],
    ];
  }

  List<Widget> _buildFreeModeContent(TrainingPlanWorkout workout) {
    final theme = Theme.of(context);
    return [
      Text('Fechas de entrenamiento', style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      TrainingDateCalendar(
        key: ValueKey('plan-calendar-${workout.trainingId}'),
        firstDate: _startDate,
        lastDate: _endDate,
        selectedDates: [for (final item in workout.dates) item.date],
        onDateToggled: (date) => _toggleDate(workout.trainingId, date),
        enabled: !_saving,
      ),
      if (workout.dates.isNotEmpty) ...[
        const Divider(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: ValueKey('plan-apply-time-${workout.trainingId}'),
            onPressed: _saving ? null : () => _applyTimeToAllDates(workout),
            icon: const Icon(Icons.schedule),
            label: const Text('Aplicar la misma hora a todos'),
          ),
        ),
        const SizedBox(height: 4),
        for (final date in workout.dates)
          _ScheduleTimeRow(
            key: ValueKey(
                'date-${workout.trainingId}-${date.date.year}-${date.date.month}-${date.date.day}'),
            label: _dateLabel(date.date),
            startMinuteOfDay: date.startMinuteOfDay,
            endMinuteOfDay: date.endMinuteOfDay,
            onSetTime: () => _editDateTime(workout, date),
            onClearTime: () => _clearDateTime(workout, date),
            enabled: !_saving,
          ),
      ],
    ];
  }
}

class _TrainingPicker extends ConsumerWidget {
  const _TrainingPicker({required this.excludedIds});

  final Set<String> excludedIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingsAsync = ref.watch(trainingsProvider);
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
                    child: Text('Añadir entrenamiento',
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
              child: trainingsAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (_, __) => Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.read(trainingsProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh),
                    label:
                        const Text('No se pudieron cargar los entrenamientos'),
                  ),
                ),
                data: (trainings) {
                  final available = trainings.where((training) {
                    return training.id != null &&
                        !excludedIds.contains(training.id);
                  }).toList();
                  if (available.isEmpty) {
                    return Center(
                      child: Text(trainings.isEmpty
                          ? 'No tienes entrenamientos creados'
                          : 'Ya están añadidos todos tus entrenamientos'),
                    );
                  }
                  return ListView.separated(
                    itemCount: available.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final training = available[index];
                      return ListTile(
                        leading: const Icon(Icons.fitness_center),
                        title: Text(training.name),
                        trailing: const Icon(Icons.add),
                        onTap: () => Navigator.pop(context, training),
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

class _ScheduleTimeRow extends StatelessWidget {
  const _ScheduleTimeRow({
    super.key,
    required this.label,
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    required this.onSetTime,
    required this.onClearTime,
    required this.enabled,
  });

  final String label;
  final int? startMinuteOfDay;
  final int? endMinuteOfDay;
  final VoidCallback onSetTime;
  final VoidCallback onClearTime;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hasTime = startMinuteOfDay != null && endMinuteOfDay != null;
    return Row(
      children: [
        Expanded(child: Text(label)),
        TextButton.icon(
          onPressed: enabled ? onSetTime : null,
          icon: const Icon(Icons.schedule_outlined),
          label: Text(hasTime
              ? '${_formatMinute(startMinuteOfDay!)} - '
                  '${_formatMinute(endMinuteOfDay!)}'
              : 'Añadir horario'),
        ),
        if (hasTime)
          IconButton(
            tooltip: 'Quitar horario',
            onPressed: enabled ? onClearTime : null,
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }
}

TimeOfDay _timeOfDayFromMinute(int minuteOfDay) => TimeOfDay(
      hour: minuteOfDay ~/ 60,
      minute: minuteOfDay % 60,
    );

String _formatMinute(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

String _dateLabel(DateTime date) =>
    '${_dayName(TrainingPlanDay.values[date.weekday - 1])} '
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _workoutScheduleSummary(
  TrainingPlanWorkout workout,
  TrainingPlanMode mode,
) {
  if (mode == TrainingPlanMode.free) {
    if (workout.dates.isEmpty) return 'Selecciona al menos una fecha';
    final count = workout.dates.length;
    return count == 1 ? '1 fecha' : '$count fechas';
  }
  if (workout.schedules.isEmpty) return 'Selecciona al menos un día';
  return workout.schedules.map((schedule) {
    final time =
        schedule.startMinuteOfDay == null || schedule.endMinuteOfDay == null
            ? ''
            : ' ${_formatMinute(schedule.startMinuteOfDay!)}'
                '-${_formatMinute(schedule.endMinuteOfDay!)}';
    return '${_dayInitial(schedule.dayOfWeek)}$time';
  }).join(' · ');
}

String _dayInitial(TrainingPlanDay day) => switch (day) {
      TrainingPlanDay.monday => 'L',
      TrainingPlanDay.tuesday => 'M',
      TrainingPlanDay.wednesday => 'X',
      TrainingPlanDay.thursday => 'J',
      TrainingPlanDay.friday => 'V',
      TrainingPlanDay.saturday => 'S',
      TrainingPlanDay.sunday => 'D',
    };

String _dayName(TrainingPlanDay day) => switch (day) {
      TrainingPlanDay.monday => 'Lunes',
      TrainingPlanDay.tuesday => 'Martes',
      TrainingPlanDay.wednesday => 'Miércoles',
      TrainingPlanDay.thursday => 'Jueves',
      TrainingPlanDay.friday => 'Viernes',
      TrainingPlanDay.saturday => 'Sábado',
      TrainingPlanDay.sunday => 'Domingo',
    };

/// Campo con autocompletado para elegir un grupo y rellenar con sus miembros
/// la lista de usuarios asignados. Es un atajo visual: no asigna el grupo.
class _GroupFillField extends StatefulWidget {
  const _GroupFillField({
    required this.groups,
    required this.enabled,
    required this.onSelected,
  });

  final List<UserGroup> groups;
  final bool enabled;
  final ValueChanged<UserGroup> onSelected;

  @override
  State<_GroupFillField> createState() => _GroupFillFieldState();
}

class _GroupFillFieldState extends State<_GroupFillField> {
  TextEditingController? _fieldController;
  FocusNode? _fieldFocusNode;
  // Cambiar la key reconstruye el Autocomplete y cierra su overlay de
  // opciones, que no se cierra solo al perder el foco con el texto vacío.
  Key _autocompleteKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    // Al volver de otra pantalla (por ejemplo, el selector de usuarios) el
    // campo no debe conservar el foco ni mostrar las opciones de grupos.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fieldFocusNode?.unfocus();
    });
  }

  @override
  void dispose() {
    _fieldFocusNode?.removeListener(_hideOptionsOnFocusLoss);
    super.dispose();
  }

  /// Al perder el foco (tocar otro input o fuera del campo) se cierran las
  /// opciones reconstruyendo el Autocomplete.
  void _hideOptionsOnFocusLoss() {
    if (_fieldFocusNode?.hasFocus == false && mounted) {
      setState(() => _autocompleteKey = UniqueKey());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<UserGroup>(
      key: _autocompleteKey,
      displayStringForOption: (group) => group.name,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return widget.groups;
        return widget.groups.where(
          (group) => group.name.toLowerCase().contains(query),
        );
      },
      onSelected: (group) {
        // Se limpia y se quita el foco: es una acción, no una asociación,
        // y si conserva el foco las opciones reaparecen al cerrar cualquier
        // diálogo posterior (calendario, selector de usuarios...).
        _fieldController?.clear();
        _fieldFocusNode?.unfocus();
        widget.onSelected(group);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _fieldController = controller;
        if (_fieldFocusNode != focusNode) {
          _fieldFocusNode?.removeListener(_hideOptionsOnFocusLoss);
          _fieldFocusNode = focusNode;
          _fieldFocusNode?.addListener(_hideOptionsOnFocusLoss);
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.sentences,
          onTap: () {
            // Si el campo ya tenía el foco, Autocomplete no reabre las
            // opciones: se fuerza perdiendo y recuperando el foco.
            if (focusNode.hasFocus) {
              focusNode.unfocus();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && widget.enabled) focusNode.requestFocus();
              });
            }
          },
          decoration: const InputDecoration(
            labelText: 'Añadir desde un grupo',
            hintText: 'Escribe el nombre del grupo',
            prefixIcon: Icon(Icons.groups_outlined),
            border: OutlineInputBorder(),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 320),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final group = options.elementAt(index);
                final count = group.members.length;
                return ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(count == 1 ? '1 miembro' : '$count miembros'),
                  onTap: () => onSelected(group),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(_formatDate(date)),
        ),
      );
}

String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year.toString().padLeft(4, '0')}';
