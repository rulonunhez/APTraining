import '../models/training_plan.dart';

enum TrainingPlanStatus {
  inProgress('En curso'),
  finished('Finalizada'),
  upcoming('Pendiente'),
  undetermined('Por determinar');

  const TrainingPlanStatus(this.label);

  final String label;
}

/// Estado según la vigencia del plan. Sin inicio o sin fin, las fechas
/// no están establecidas y el estado es [TrainingPlanStatus.undetermined].
TrainingPlanStatus trainingPlanStatusOf(TrainingPlan plan, {DateTime? today}) {
  final start = plan.startDate;
  final end = plan.endDate;
  if (start == null || end == null) return TrainingPlanStatus.undetermined;

  final now = _dateOnly(today ?? DateTime.now());
  if (_dateOnly(end).isBefore(now)) return TrainingPlanStatus.finished;
  if (_dateOnly(start).isAfter(now)) return TrainingPlanStatus.upcoming;
  return TrainingPlanStatus.inProgress;
}

/// Filtro de la lista de planes.
///
/// - [nameQuery]: texto buscado en el nombre del plan.
/// - [trainingIds]: el plan debe incluir todos estos entrenamientos.
/// - [status]: si no es null, solo planes con ese estado.
class TrainingPlanFilter {
  const TrainingPlanFilter({
    this.nameQuery = '',
    this.trainingIds = const {},
    this.status,
  });

  final String nameQuery;
  final Set<String> trainingIds;
  final TrainingPlanStatus? status;
}

List<TrainingPlan> filterTrainingPlans(
  List<TrainingPlan> plans,
  TrainingPlanFilter filter, {
  DateTime? today,
}) {
  final query = filter.nameQuery.trim().toLowerCase();
  return plans.where((plan) {
    if (query.isNotEmpty && !plan.name.toLowerCase().contains(query)) {
      return false;
    }
    final planTrainingIds = plan.workouts.map((w) => w.trainingId).toSet();
    if (!planTrainingIds.containsAll(filter.trainingIds)) return false;
    if (filter.status != null &&
        trainingPlanStatusOf(plan, today: today) != filter.status) {
      return false;
    }
    return true;
  }).toList();
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
