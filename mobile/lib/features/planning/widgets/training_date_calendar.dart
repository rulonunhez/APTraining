import 'package:flutter/material.dart';

const _monthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

class TrainingDateCalendar extends StatefulWidget {
  const TrainingDateCalendar({
    super.key,
    required this.firstDate,
    required this.lastDate,
    required this.selectedDates,
    required this.onDateToggled,
    this.enabled = true,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final List<DateTime> selectedDates;
  final ValueChanged<DateTime> onDateToggled;
  final bool enabled;

  @override
  State<TrainingDateCalendar> createState() => _TrainingDateCalendarState();
}

class _TrainingDateCalendarState extends State<TrainingDateCalendar> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final first = DateUtils.dateOnly(widget.firstDate);
    final initial = widget.selectedDates.isEmpty
        ? first
        : DateUtils.dateOnly(widget.selectedDates.first);
    _visibleMonth = DateTime(initial.year, initial.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final first = DateUtils.dateOnly(widget.firstDate);
    final last = DateUtils.dateOnly(widget.lastDate);
    final monthStart = DateTime(_visibleMonth.year, _visibleMonth.month);
    final canGoBack = DateTime(monthStart.year, monthStart.month - 1, 1)
        .isAfter(DateTime(first.year, first.month - 1, 1));
    final canGoForward = DateTime(monthStart.year, monthStart.month + 1, 1)
        .isBefore(DateTime(last.year, last.month + 1, 1));

    // Monday-first grid: start on the Monday on or before the 1st of the month.
    final leadingDays = monthStart.weekday - DateTime.monday;
    final gridStart =
        DateTime(monthStart.year, monthStart.month, 1 - leadingDays);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              onPressed:
                  widget.enabled && canGoBack ? () => _changeMonth(-1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_monthNames[monthStart.month - 1]} ${monthStart.year}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed:
                  widget.enabled && canGoForward ? () => _changeMonth(1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final initial in const ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
              Expanded(
                child: Text(
                  initial,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          children: [
            for (var offset = 0; offset < 42; offset++)
              _buildDay(
                context,
                day: DateTime(
                    gridStart.year, gridStart.month, gridStart.day + offset),
                monthStart: monthStart,
                first: first,
                last: last,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDay(
    BuildContext context, {
    required DateTime day,
    required DateTime monthStart,
    required DateTime first,
    required DateTime last,
  }) {
    if (day.month != monthStart.month) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final inRange = !day.isBefore(first) && !day.isAfter(last);
    final enabled = widget.enabled && inRange;
    final selected = widget.selectedDates.any(
      (date) => DateUtils.isSameDay(date, day),
    );
    final isToday = DateUtils.isSameDay(day, DateTime.now());

    final Color textColor;
    if (selected) {
      textColor = colors.onPrimary;
    } else if (!inRange) {
      textColor = theme.disabledColor;
    } else {
      textColor = colors.onSurface;
    }

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: enabled ? () => widget.onDateToggled(day) : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? colors.primary : null,
          border:
              isToday && !selected ? Border.all(color: colors.primary) : null,
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: textColor,
            fontWeight: selected ? FontWeight.w700 : null,
          ),
        ),
      ),
    );
  }
}
