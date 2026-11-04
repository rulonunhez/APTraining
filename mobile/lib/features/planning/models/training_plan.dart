import '../../users/models/app_user.dart';

enum TrainingPlanDay {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  String toApiValue() => name.toUpperCase();

  static TrainingPlanDay fromApiValue(String value) =>
      TrainingPlanDay.values.firstWhere(
        (day) => day.toApiValue() == value.toUpperCase(),
        orElse: () => throw FormatException('Unknown day of week: $value'),
      );
}

enum TrainingPlanMode {
  weekly,
  free;

  String toApiValue() => name.toUpperCase();

  static TrainingPlanMode fromApiValue(String? value) => value == null
      ? TrainingPlanMode.weekly
      : TrainingPlanMode.values.firstWhere(
          (mode) => mode.toApiValue() == value.toUpperCase(),
          orElse: () => throw FormatException('Unknown plan mode: $value'),
        );
}

typedef TrainingPlanSlot = ({int? startMinuteOfDay, int? endMinuteOfDay});

class TrainingPlanSchedule {
  const TrainingPlanSchedule({
    required this.dayOfWeek,
    this.startMinuteOfDay,
    this.endMinuteOfDay,
  });

  final TrainingPlanDay dayOfWeek;
  final int? startMinuteOfDay;
  final int? endMinuteOfDay;

  factory TrainingPlanSchedule.fromJson(Map<String, dynamic> json) =>
      TrainingPlanSchedule(
        dayOfWeek: TrainingPlanDay.fromApiValue(json['dayOfWeek'] as String),
        startMinuteOfDay: _parseTime(json['startTime'] as String?),
        endMinuteOfDay: _parseTime(json['endTime'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek.toApiValue(),
        'startTime': _formatTime(startMinuteOfDay),
        'endTime': _formatTime(endMinuteOfDay),
      };

  static int? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2 || parts.length > 3) {
      throw FormatException('Invalid local time: $value');
    }

    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }

  static String? _formatTime(int? minuteOfDay) {
    if (minuteOfDay == null) return null;
    final hour = minuteOfDay ~/ 60;
    final minute = minuteOfDay % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00';
  }
}

class TrainingPlanDate {
  const TrainingPlanDate({
    required this.date,
    this.startMinuteOfDay,
    this.endMinuteOfDay,
  });

  final DateTime date;
  final int? startMinuteOfDay;
  final int? endMinuteOfDay;

  factory TrainingPlanDate.fromJson(Map<String, dynamic> json) =>
      TrainingPlanDate(
        date: DateTime.parse(json['date'] as String),
        startMinuteOfDay:
            TrainingPlanSchedule._parseTime(json['startTime'] as String?),
        endMinuteOfDay:
            TrainingPlanSchedule._parseTime(json['endTime'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'date': TrainingPlan._formatDate(date),
        'startTime': TrainingPlanSchedule._formatTime(startMinuteOfDay),
        'endTime': TrainingPlanSchedule._formatTime(endMinuteOfDay),
      };
}

class TrainingPlanWorkout {
  const TrainingPlanWorkout({
    required this.trainingId,
    required this.schedules,
    this.dates = const [],
    this.trainingName,
    this.orderIndex = 0,
  });

  final String trainingId;
  final String? trainingName;
  final int orderIndex;
  final List<TrainingPlanSchedule> schedules;
  final List<TrainingPlanDate> dates;

  TrainingPlanSlot? slotOn(DateTime date) {
    for (final schedule in schedules) {
      if (schedule.dayOfWeek.index == date.weekday - 1) {
        return (
          startMinuteOfDay: schedule.startMinuteOfDay,
          endMinuteOfDay: schedule.endMinuteOfDay,
        );
      }
    }
    for (final scheduled in dates) {
      if (_isSameDay(scheduled.date, date)) {
        return (
          startMinuteOfDay: scheduled.startMinuteOfDay,
          endMinuteOfDay: scheduled.endMinuteOfDay,
        );
      }
    }
    return null;
  }

  bool isScheduledOn(DateTime date) => slotOn(date) != null;

  TrainingPlanWorkout copyWith({
    int? orderIndex,
    List<TrainingPlanSchedule>? schedules,
    List<TrainingPlanDate>? dates,
  }) =>
      TrainingPlanWorkout(
        trainingId: trainingId,
        trainingName: trainingName,
        orderIndex: orderIndex ?? this.orderIndex,
        schedules: schedules ?? this.schedules,
        dates: dates ?? this.dates,
      );

  factory TrainingPlanWorkout.fromJson(Map<String, dynamic> json) =>
      TrainingPlanWorkout(
        trainingId: json['trainingId'] as String,
        trainingName: json['trainingName'] as String?,
        orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
        schedules: (json['schedules'] as List<dynamic>? ?? const [])
            .map((item) => TrainingPlanSchedule.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(),
        dates: (json['dates'] as List<dynamic>? ?? const [])
            .map((item) => TrainingPlanDate.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'trainingId': trainingId,
        'orderIndex': orderIndex,
        'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
        'dates': dates.map((date) => date.toJson()).toList(),
      };
}

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

class TrainingPlan {
  const TrainingPlan({
    this.id,
    required this.name,
    this.mode = TrainingPlanMode.weekly,
    this.startDate,
    this.endDate,
    this.workouts = const [],
    this.assignedUserIds = const [],
    this.assignedGroupIds = const [],
    this.assignedUsers = const [],
    this.createdByMe = true,
    this.assignedByUsername,
  });

  final String? id;
  final String name;
  final TrainingPlanMode mode;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<TrainingPlanWorkout> workouts;

  /// Ids de usuarios asignados individualmente (escritura, solo creador).
  final List<String> assignedUserIds;

  /// Ids de grupos asignados (escritura, solo creador). El backend los
  /// expande a asignaciones individuales al guardar.
  final List<String> assignedGroupIds;

  /// Usuarios con el plan asignado (lectura, solo creador).
  final List<AppUser> assignedUsers;

  /// false cuando el plan llega por asignación de un entrenador.
  final bool createdByMe;

  /// Nombre del entrenador que asignó el plan (lectura, solo asignado).
  final String? assignedByUsername;

  bool isActiveOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final startsOn = startDate == null
        ? null
        : DateTime(startDate!.year, startDate!.month, startDate!.day);
    final endsOn = endDate == null
        ? null
        : DateTime(endDate!.year, endDate!.month, endDate!.day);

    return (startsOn == null || !day.isBefore(startsOn)) &&
        (endsOn == null || !day.isAfter(endsOn));
  }

  factory TrainingPlan.fromJson(Map<String, dynamic> json) => TrainingPlan(
        id: json['id'] as String?,
        name: json['name'] as String,
        mode: TrainingPlanMode.fromApiValue(json['mode'] as String?),
        startDate: json['startDate'] == null
            ? null
            : DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] == null
            ? null
            : DateTime.parse(json['endDate'] as String),
        workouts: (json['workouts'] as List<dynamic>? ?? const [])
            .map((item) => TrainingPlanWorkout.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(),
        assignedUserIds: (json['assignedUserIds'] as List<dynamic>? ?? const [])
            .map((item) => item as String)
            .toList(),
        assignedGroupIds:
            (json['assignedGroupIds'] as List<dynamic>? ?? const [])
                .map((item) => item as String)
                .toList(),
        assignedUsers: (json['assignedUsers'] as List<dynamic>? ?? const [])
            .map((item) => AppUser.fromJson(item as Map<String, dynamic>))
            .toList(),
        createdByMe: json['createdByMe'] as bool? ?? true,
        assignedByUsername: json['assignedByUsername'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'mode': mode.toApiValue(),
        'startDate': startDate == null ? null : _formatDate(startDate!),
        'endDate': endDate == null ? null : _formatDate(endDate!),
        'workouts': workouts.map((workout) => workout.toJson()).toList(),
        'assignedUserIds': assignedUserIds,
        'assignedGroupIds': assignedGroupIds,
      };

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
