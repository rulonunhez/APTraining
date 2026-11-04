import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/features/planning/models/training_plan.dart';
import 'package:ap_training/features/planning/providers/training_plans_provider.dart';
import 'package:ap_training/features/planning/repositories/training_plan_repository.dart';
import 'package:ap_training/features/planning/screens/planning_screen.dart';
import 'package:ap_training/features/planning/screens/training_plan_editor_screen.dart';
import 'package:ap_training/features/workout/models/training.dart';
import 'package:ap_training/features/workout/providers/trainings_provider.dart';
import 'package:ap_training/shared/widgets/search_field.dart';

void main() {
  testWidgets('shows finished plans with a distinct status', (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final repository = _FakeTrainingPlanRepository([
      TrainingPlan(
        id: 'finished-plan',
        name: 'Bloque anterior',
        startDate: today.subtract(const Duration(days: 30)),
        endDate: today.subtract(const Duration(days: 1)),
        workouts: const [
          TrainingPlanWorkout(
            trainingId: 'training-1',
            trainingName: 'Día A',
            schedules: [],
          ),
        ],
      ),
      TrainingPlan(
        id: 'active-plan',
        name: 'Bloque actual',
        startDate: today,
        endDate: today,
      ),
    ]);

    await tester.pumpWidget(_planningApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Bloque anterior'), findsOneWidget);
    expect(find.text('Finalizada'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.text('1 entrenamiento · Día A'), findsOneWidget);
    expect(find.text('Bloque actual'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
  });

  testWidgets('weekly view shows overlapping plans only within their dates',
      (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final activeDay = TrainingPlanDay.values[today.weekday - 1];
    final plans = [
      for (final entry in [
        ('Plan A', 'Día A', TrainingPlanDay.monday),
        ('Plan B', 'Día B', TrainingPlanDay.monday),
      ])
        TrainingPlan(
          id: entry.$1,
          name: entry.$1,
          startDate: today.subtract(const Duration(days: 7)),
          endDate: today.add(const Duration(days: 6)),
          workouts: [
            TrainingPlanWorkout(
              trainingId: entry.$1,
              trainingName: entry.$2,
              schedules: [
                TrainingPlanSchedule(
                  dayOfWeek: activeDay,
                  startMinuteOfDay: 19 * 60,
                  endMinuteOfDay: 20 * 60,
                ),
              ],
            ),
          ],
        ),
      TrainingPlan(
        id: 'expired-plan',
        name: 'Plan vencido',
        startDate: today.subtract(const Duration(days: 14)),
        endDate: today.subtract(const Duration(days: 1)),
        workouts: [
          TrainingPlanWorkout(
            trainingId: 'expired-training',
            trainingName: 'No debe aparecer',
            schedules: [TrainingPlanSchedule(dayOfWeek: activeDay)],
          ),
        ],
      ),
    ];

    await tester.pumpWidget(_planningApp(_FakeTrainingPlanRepository(plans)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semana'));
    await tester.pumpAndSettle();

    expect(find.text('Plan A'), findsOneWidget);
    expect(find.text('Plan B'), findsOneWidget);
    expect(find.text('Día A · 19:00 - 20:00'), findsOneWidget);
    expect(find.text('Día B · 19:00 - 20:00'), findsOneWidget);
    expect(find.text('No debe aparecer'), findsNothing);

    await tester.tap(find.byTooltip('Semana siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Plan A'), findsNothing);
    expect(find.text('Plan B'), findsNothing);
  });

  testWidgets('filters plans by name only in the plans view', (tester) async {
    final repository = _FakeTrainingPlanRepository([
      TrainingPlan(id: 'p1', name: 'Fuerza invierno'),
      TrainingPlan(id: 'p2', name: 'Definición'),
    ]);

    await tester.pumpWidget(_planningApp(repository));
    await tester.pumpAndSettle();

    final searchInput = find.descendant(
      of: find.byType(SearchField),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchInput, 'defin');
    await tester.pumpAndSettle();

    expect(find.text('Definición'), findsOneWidget);
    expect(find.text('Fuerza invierno'), findsNothing);

    await tester.enterText(searchInput, 'nada');
    await tester.pumpAndSettle();
    expect(find.text('No hay planes que coincidan con los filtros'),
        findsOneWidget);

    await tester.tap(find.text('Semana'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchField), findsNothing);
  });

  testWidgets('confirms deletion and removes the plan from the list',
      (tester) async {
    final repository = _FakeTrainingPlanRepository([
      TrainingPlan(
        id: 'plan-1',
        name: 'Plan temporal',
        startDate: DateTime(2026, 10, 5),
        endDate: DateTime(2026, 11, 5),
      ),
    ]);

    await tester.pumpWidget(_planningApp(repository));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Plan temporal'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(repository.deletedIds, ['plan-1']);
    expect(find.text('Plan temporal'), findsNothing);
  });

  testWidgets('empty state offers to create a plan', (tester) async {
    final repository = _FakeTrainingPlanRepository([]);

    await tester.pumpWidget(_planningApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no tienes planificaciones'), findsOneWidget);
    expect(find.text('Crear'), findsOneWidget);
  });

  testWidgets('load failure shows a retry action', (tester) async {
    final repository = _FakeTrainingPlanRepository([])..failLoading = true;

    await tester.pumpWidget(_planningApp(repository));
    await tester.pumpAndSettle();

    expect(
        find.text('No se pudieron cargar las planificaciones'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('create editor submits plan name and date range', (tester) async {
    _useTallScreen(tester);
    final repository = _FakeTrainingPlanRepository([]);
    await tester.pumpWidget(_editorApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('trainingPlanName')), 'Bloque A');
    await tester.tap(find.text('Crear planificación'));
    await tester.pumpAndSettle();

    expect(repository.createdPlan?.name, 'Bloque A');
    expect(repository.createdPlan?.startDate, isNotNull);
    expect(repository.createdPlan?.endDate, isNotNull);
    expect(repository.createdPlan?.workouts, isEmpty);
  });

  testWidgets('edit editor keeps existing workout assignments', (tester) async {
    _useTallScreen(tester);
    final existingPlan = TrainingPlan(
      id: 'plan-1',
      name: 'Bloque original',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 11, 5),
      workouts: const [
        TrainingPlanWorkout(
          trainingId: 'training-1',
          trainingName: 'Día A',
          schedules: [
            TrainingPlanSchedule(dayOfWeek: TrainingPlanDay.monday),
          ],
        ),
      ],
    );
    final repository = _FakeTrainingPlanRepository([existingPlan]);
    await tester.pumpWidget(_editorApp(repository, planId: 'plan-1'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('trainingPlanName')), 'Bloque editado');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(repository.updatedPlan?.name, 'Bloque editado');
    expect(repository.updatedPlan?.workouts.single.trainingId, 'training-1');
    expect(repository.updatedPlan?.workouts.single.schedules.single.dayOfWeek,
        TrainingPlanDay.monday);
  });

  testWidgets('selects a training once and saves multiple weekdays',
      (tester) async {
    _useTallScreen(tester);
    final repository = _FakeTrainingPlanRepository([]);
    final trainings = [
      const Training(id: 'training-1', name: 'Día A'),
      const Training(id: 'training-2', name: 'Día B'),
    ];
    await tester.pumpWidget(_editorApp(repository, trainings: trainings));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Añadir entrenamiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Día A').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('plan-day-training-1-monday')),
    );
    await tester.tap(
      find.byKey(const ValueKey('plan-day-training-1-friday')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Añadir entrenamiento'));
    await tester.pumpAndSettle();
    expect(find.text('Día A'), findsOneWidget);
    expect(find.text('Día B'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('trainingPlanName')), 'Bloque semanal');
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    final savedWorkout = repository.createdPlan!.workouts.single;
    expect(savedWorkout.trainingId, 'training-1');
    expect(
      savedWorkout.schedules.map((schedule) => schedule.dayOfWeek),
      [TrainingPlanDay.monday, TrainingPlanDay.friday],
    );
    expect(
        savedWorkout.schedules.every((schedule) =>
            schedule.startMinuteOfDay == null &&
            schedule.endMinuteOfDay == null),
        isTrue);
  });

  testWidgets('creates a free-mode plan with the selected calendar dates',
      (tester) async {
    _useTallScreen(tester);
    final repository = _FakeTrainingPlanRepository([]);
    await tester.pumpWidget(
      _editorApp(
        repository,
        trainings: const [Training(id: 'training-1', name: 'Día A')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Libre'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir entrenamiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Día A').last);
    await tester.pumpAndSettle();

    final today = DateUtils.dateOnly(DateTime.now());
    await tester.tap(find.text('${today.day}').first);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('trainingPlanName')), 'Bloque libre');
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    final plan = repository.createdPlan!;
    expect(plan.mode, TrainingPlanMode.free);
    expect(plan.workouts.single.schedules, isEmpty);
    expect(plan.workouts.single.dates.single.date, today);
  });

  testWidgets('applies one time slot to every free-mode date at once',
      (tester) async {
    _useTallScreen(tester);
    final repository = _FakeTrainingPlanRepository([]);
    await tester.pumpWidget(
      _editorApp(
        repository,
        trainings: const [Training(id: 'training-1', name: 'Día A')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Libre'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir entrenamiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Día A').last);
    await tester.pumpAndSettle();

    final today = DateUtils.dateOnly(DateTime.now());
    await tester.tap(find.text('${today.day}').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-apply-time-training-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('19:00 - 20:00'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('trainingPlanName')), 'Bloque hora común');
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    final savedDate = repository.createdPlan!.workouts.single.dates.single;
    expect(savedDate.startMinuteOfDay, 19 * 60);
    expect(savedDate.endMinuteOfDay, 20 * 60);
  });

  testWidgets('sets optional start and end times for a scheduled day',
      (tester) async {
    _useTallScreen(tester);
    final repository = _FakeTrainingPlanRepository([]);
    await tester.pumpWidget(
      _editorApp(
        repository,
        trainings: const [Training(id: 'training-1', name: 'Día A')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Añadir entrenamiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Día A'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('plan-day-training-1-monday')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir horario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('19:00 - 20:00'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('trainingPlanName')), 'Bloque horario');
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    final savedSchedule =
        repository.createdPlan!.workouts.single.schedules.single;
    expect(savedSchedule.startMinuteOfDay, 19 * 60);
    expect(savedSchedule.endMinuteOfDay, 20 * 60);
  });

  testWidgets('requires at least one weekday for each selected training',
      (tester) async {
    final repository = _FakeTrainingPlanRepository([]);
    await tester.pumpWidget(
      _editorApp(
        repository,
        trainings: const [Training(id: 'training-1', name: 'Día A')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Añadir entrenamiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Día A'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('trainingPlanName')), 'Bloque incompleto');
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.createdPlan, isNull);
    expect(
      find.text('Selecciona al menos un día para cada entrenamiento'),
      findsOneWidget,
    );
  });
}

void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _planningApp(_FakeTrainingPlanRepository repository) => ProviderScope(
      overrides: [
        trainingPlanRepositoryProvider.overrideWithValue(repository),
        trainingsProvider.overrideWith(() => _FakeTrainingsNotifier(const [])),
      ],
      child: const MaterialApp(home: PlanningScreen()),
    );

Widget _editorApp(
  _FakeTrainingPlanRepository repository, {
  String? planId,
  List<Training> trainings = const [],
}) =>
    ProviderScope(
      overrides: [
        trainingPlanRepositoryProvider.overrideWithValue(repository),
        trainingsProvider.overrideWith(
          () => _FakeTrainingsNotifier(trainings),
        ),
      ],
      child: MaterialApp(home: TrainingPlanEditorScreen(planId: planId)),
    );

class _FakeTrainingsNotifier extends TrainingsNotifier {
  _FakeTrainingsNotifier(this.trainings);

  final List<Training> trainings;

  @override
  Future<List<Training>> build() async => trainings;
}

class _FakeTrainingPlanRepository implements TrainingPlanRepository {
  _FakeTrainingPlanRepository(this.plans);

  final List<TrainingPlan> plans;
  final List<String> deletedIds = [];
  bool failLoading = false;
  TrainingPlan? createdPlan;
  TrainingPlan? updatedPlan;

  @override
  Future<List<TrainingPlan>> getTrainingPlans() async {
    if (failLoading) throw Exception('offline');
    return plans;
  }

  @override
  Future<TrainingPlan> getTrainingPlan(String id) async =>
      plans.firstWhere((plan) => plan.id == id);

  @override
  Future<TrainingPlan> createTrainingPlan(TrainingPlan plan) async {
    createdPlan = plan;
    return plan;
  }

  @override
  Future<TrainingPlan> updateTrainingPlan(String id, TrainingPlan plan) async {
    updatedPlan = plan;
    return plan;
  }

  @override
  Future<void> deleteTrainingPlan(String id) async {
    deletedIds.add(id);
  }
}
