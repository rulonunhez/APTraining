import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/features/planning/models/training_plan.dart';
import 'package:ap_training/features/planning/utils/training_plan_filter.dart';

void main() {
  final today = DateTime(2024, 6, 15);

  TrainingPlan plan({
    required String name,
    DateTime? start,
    DateTime? end,
    List<String> trainingIds = const [],
  }) =>
      TrainingPlan(
        id: name,
        name: name,
        startDate: start,
        endDate: end,
        workouts: [
          for (final id in trainingIds)
            TrainingPlanWorkout(trainingId: id, schedules: const []),
        ],
      );

  group('trainingPlanStatusOf', () {
    test('sin fechas es por determinar', () {
      expect(
        trainingPlanStatusOf(plan(name: 'a'), today: today),
        TrainingPlanStatus.undetermined,
      );
    });

    test('sin fecha de fin es por determinar', () {
      expect(
        trainingPlanStatusOf(
          plan(name: 'a', start: DateTime(2024, 6, 1)),
          today: today,
        ),
        TrainingPlanStatus.undetermined,
      );
    });

    test('fin anterior a hoy es finalizada', () {
      expect(
        trainingPlanStatusOf(
          plan(
            name: 'a',
            start: DateTime(2024, 5, 1),
            end: DateTime(2024, 6, 14),
          ),
          today: today,
        ),
        TrainingPlanStatus.finished,
      );
    });

    test('inicio posterior a hoy es pendiente', () {
      expect(
        trainingPlanStatusOf(
          plan(
            name: 'a',
            start: DateTime(2024, 6, 16),
            end: DateTime(2024, 7, 1),
          ),
          today: today,
        ),
        TrainingPlanStatus.upcoming,
      );
    });

    test('hoy dentro de la vigencia es en curso', () {
      expect(
        trainingPlanStatusOf(
          plan(
            name: 'a',
            start: DateTime(2024, 6, 15),
            end: DateTime(2024, 6, 15),
          ),
          today: today,
        ),
        TrainingPlanStatus.inProgress,
      );
    });
  });

  group('filterTrainingPlans', () {
    final plans = [
      plan(
        name: 'Fuerza invierno',
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 2, 1),
        trainingIds: const ['t1', 't2'],
      ),
      plan(
        name: 'Definición',
        start: DateTime(2024, 6, 1),
        end: DateTime(2024, 7, 1),
        trainingIds: const ['t1'],
      ),
      plan(name: 'Sin fechas', trainingIds: const ['t3']),
    ];

    List<String> names(TrainingPlanFilter filter) => filterTrainingPlans(
          plans,
          filter,
          today: today,
        ).map((p) => p.name).toList();

    test('sin filtros devuelve todos', () {
      expect(names(const TrainingPlanFilter()), hasLength(3));
    });

    test('busca por nombre sin distinguir mayúsculas', () {
      expect(
        names(const TrainingPlanFilter(nameQuery: '  FUERZA ')),
        ['Fuerza invierno'],
      );
    });

    test('con varios entrenos exige que estén todos', () {
      expect(
        names(const TrainingPlanFilter(trainingIds: {'t1', 't2'})),
        ['Fuerza invierno'],
      );
    });

    test('filtra por estado', () {
      expect(
        names(const TrainingPlanFilter(status: TrainingPlanStatus.undetermined)),
        ['Sin fechas'],
      );
      expect(
        names(const TrainingPlanFilter(status: TrainingPlanStatus.inProgress)),
        ['Definición'],
      );
    });

    test('combina nombre, entreno y estado', () {
      expect(
        names(const TrainingPlanFilter(
          nameQuery: 'defin',
          trainingIds: {'t1'},
          status: TrainingPlanStatus.inProgress,
        )),
        ['Definición'],
      );
    });
  });
}
