import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ap_training/core/client/api_client.dart';
import 'package:ap_training/features/planning/models/training_plan.dart';
import 'package:ap_training/features/planning/providers/training_plans_provider.dart';
import 'package:ap_training/features/exercise/data/exercise_remote_data_source.dart';
import 'package:ap_training/features/exercise/models/exercise.dart';
import 'package:ap_training/features/exercise/providers/exercises_provider.dart';
import 'package:ap_training/features/workout/models/training.dart';
import 'package:ap_training/features/workout/models/workout_history_entry.dart';
import 'package:ap_training/features/workout/models/workout_history_filter.dart';
import 'package:ap_training/features/workout/providers/trainings_provider.dart';
import 'package:ap_training/features/workout/providers/workout_history_provider.dart';
import 'package:ap_training/features/workout/repositories/workout_history_repository.dart';
import 'package:ap_training/features/workout/screens/workout_mode_screen.dart';
import 'package:ap_training/features/workout/screens/workout_session_screen.dart';
import 'package:ap_training/shared/screens/main_screen.dart';

void main() {
  testWidgets(
      'shows today and other trainings, deduplicates and opens a session',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    final today = DateUtils.dateOnly(DateTime.now());
    final todayDay = TrainingPlanDay.values[today.weekday - 1];
    final nextDay = TrainingPlanDay.values[today.weekday % 7];
    final workout = _training();
    final trainings = [
      workout,
      const Training(id: 'training-2', name: 'Pierna'),
      const Training(id: 'training-3', name: 'Accesorios'),
    ];
    final plans = [
      TrainingPlan(
        id: 'plan-a',
        name: 'Plan A',
        startDate: today.subtract(const Duration(days: 7)),
        endDate: today.add(const Duration(days: 7)),
        workouts: [
          TrainingPlanWorkout(
            trainingId: 'training-1',
            trainingName: 'Torso',
            schedules: [
              TrainingPlanSchedule(
                dayOfWeek: todayDay,
                startMinuteOfDay: 19 * 60,
                endMinuteOfDay: 20 * 60,
              ),
            ],
          ),
        ],
      ),
      TrainingPlan(
        id: 'plan-b',
        name: 'Plan B',
        workouts: [
          TrainingPlanWorkout(
            trainingId: 'training-1',
            trainingName: 'Torso',
            schedules: [TrainingPlanSchedule(dayOfWeek: todayDay)],
          ),
        ],
      ),
      TrainingPlan(
        id: 'expired',
        name: 'Plan vencido',
        startDate: today.subtract(const Duration(days: 14)),
        endDate: today.subtract(const Duration(days: 1)),
        workouts: [
          TrainingPlanWorkout(
            trainingId: 'training-2',
            trainingName: 'Pierna',
            schedules: [TrainingPlanSchedule(dayOfWeek: todayDay)],
          ),
        ],
      ),
      TrainingPlan(
        id: 'wrong-day',
        name: 'Otro día',
        startDate: today.subtract(const Duration(days: 1)),
        endDate: today.add(const Duration(days: 1)),
        workouts: [
          TrainingPlanWorkout(
            trainingId: 'training-3',
            trainingName: 'Accesorios',
            schedules: [TrainingPlanSchedule(dayOfWeek: nextDay)],
          ),
        ],
      ),
    ];
    final exerciseDataSource = _FakeExerciseRemoteDataSource();
    final workoutHistoryRepository = _FakeWorkoutHistoryRepository();
    final trainingsNotifier = _FakeTrainingsNotifier(trainings);

    final router = GoRouter(
      initialLocation: '/planning',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainScreen(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/planning',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Planificación de prueba')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/workout',
                  builder: (context, state) => const WorkoutModeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/workouts',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Entrenamientos de prueba')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/exercises',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Ejercicios de prueba')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Perfil de prueba')),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/workout/session/:trainingId',
          builder: (context, state) => WorkoutSessionScreen(
            trainingId: state.pathParameters['trainingId']!,
            initialTraining: state.extra as Training?,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseRemoteDataSourceProvider
              .overrideWithValue(exerciseDataSource),
          workoutHistoryRepositoryProvider
              .overrideWithValue(workoutHistoryRepository),
          trainingsProvider.overrideWith(() => trainingsNotifier),
          trainingPlansProvider.overrideWith(
            () => _FakeTrainingPlansNotifier(plans),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Programados para hoy'), findsOneWidget);
    expect(find.text('Otros entrenamientos'), findsOneWidget);
    expect(find.text('Torso'), findsOneWidget);
    expect(find.text('Pierna'), findsOneWidget);
    expect(find.text('Accesorios'), findsOneWidget);
    expect(find.textContaining('Plan A'), findsOneWidget);
    expect(find.textContaining('Plan B'), findsOneWidget);
    expect(find.textContaining('19:00 - 20:00'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(exerciseDataSource.requestedIds, isEmpty);

    await tester.tap(find.text('Torso'));
    await tester.pumpAndSettle();

    // Un ejercicio por pantalla: empieza por el de menor orderIndex.
    expect(find.text('Sentadilla'), findsOneWidget);
    expect(find.text('Press inclinado'), findsNothing);
    expect(find.text('Ejercicio 1 de 2'), findsOneWidget);
    expect(find.text('3 series'), findsOneWidget);
    expect(find.text('10 reps'), findsOneWidget);
    expect(find.text('40 kg'), findsOneWidget);
    expect(find.text('RPE 7'), findsOneWidget);
    expect(exerciseDataSource.requestedIds,
        unorderedEquals(['exercise-1', 'exercise-2']));

    // Marcar una serie arranca el descanso por defecto de 30 s.
    await tester.tap(find.byKey(const ValueKey('workout-set-0-0')));
    await tester.pump();
    expect(find.textContaining('Descanso · 0:30'), findsOneWidget);
    await tester.tap(find.text('Saltar'));
    await tester.pump();
    expect(find.textContaining('Descanso'), findsNothing);

    // Se puede avanzar sin completar las series y volver atrás.
    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Press inclinado'), findsOneWidget);
    expect(find.text('Ejercicio 2 de 2'), findsOneWidget);
    expect(find.text('8-10 reps'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('Sentadilla'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Fin de Torso'), findsOneWidget);
    expect(find.text('2 ejercicios · 7 series'), findsOneWidget);
    expect(find.text('Entrenamiento finalizado'), findsNothing);

    await tester.tap(find.text('Finalizar entrenamiento'));
    await tester.pumpAndSettle();
    expect(find.text('Entrenamiento finalizado'), findsOneWidget);
    expect(find.text('2 ejercicios · 7 series'), findsOneWidget);
    expect(find.byTooltip('Salir del entrenamiento'), findsOneWidget);
    expect(workoutHistoryRepository.recordedEntries, isEmpty);

    await tester.tap(find.text('Guardar actividad'));
    await tester.pumpAndSettle();
    expect(find.text('Modificar valores'), findsOneWidget);
    await tester.tap(find.text('Modificar'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('workout-series-exercise-1')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('workout-repetitions-exercise-1')),
      '6',
    );
    await tester.enterText(
      find.byKey(const ValueKey('workout-repetitions-max-exercise-1')),
      '8',
    );
    await tester.enterText(
      find.byKey(const ValueKey('workout-load-exercise-1')),
      '55.5',
    );
    await tester.tap(find.byKey(const ValueKey('workout-rpe-exercise-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar valores'));
    await tester.pumpAndSettle();

    expect(find.text('Actualizar próximos entrenamientos'), findsOneWidget);
    await tester.tap(find.text('Actualizar plantilla'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar series'), findsOneWidget);
    await tester.tap(find.text('Guardar series'));
    await tester.pumpAndSettle();

    expect(workoutHistoryRepository.recordedEntries, hasLength(1));
    expect(workoutHistoryRepository.recordedEntries.single.trainingId,
        'training-1');
    final savedExercise = workoutHistoryRepository
        .recordedEntries.single.exercises
        .singleWhere((exercise) => exercise.exerciseName == 'Press inclinado');
    expect(savedExercise.series, 5);
    expect(savedExercise.repetitions, 6);
    expect(savedExercise.repetitionsMax, 8);
    expect(savedExercise.load, 55.5);
    expect(savedExercise.rpe, 9);
    expect(savedExercise.sets, hasLength(5));
    expect(trainingsNotifier.updatedTraining?.exercises.first.series, 5);
    expect(find.text('Actividad guardada y plantilla actualizada'),
        findsOneWidget);

    await tester.tap(find.text('Volver a Workout'));
    await tester.pumpAndSettle();

    expect(find.text('Programados para hoy'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Perfil de prueba'), findsOneWidget);
  });
}

Training _training() => const Training(
      id: 'training-1',
      name: 'Torso',
      exercises: [
        TrainingExercise(
          exerciseId: 'exercise-1',
          exerciseName: 'Press inclinado',
          repetitions: 8,
          repetitionsMax: 10,
          repetitionType: TrainingRepetitionType.range,
          series: 4,
          rpe: 8,
          measurementUnit: TrainingLoadUnit.kg,
          load: 50,
          orderIndex: 1,
          hasVideo: true,
        ),
        TrainingExercise(
          exerciseId: 'exercise-2',
          exerciseName: 'Sentadilla',
          repetitions: 10,
          repetitionType: TrainingRepetitionType.fixed,
          series: 3,
          rpe: 7,
          measurementUnit: TrainingLoadUnit.kg,
          load: 40,
          orderIndex: 0,
        ),
      ],
    );

class _FakeTrainingsNotifier extends TrainingsNotifier {
  _FakeTrainingsNotifier(this.trainings);

  final List<Training> trainings;
  Training? updatedTraining;

  @override
  Future<List<Training>> build() async => trainings;

  @override
  Future<Training> updateTraining(String id, Training training) async {
    updatedTraining = training;
    return training;
  }
}

class _FakeExerciseRemoteDataSource extends ExerciseRemoteDataSource {
  _FakeExerciseRemoteDataSource() : super(ApiClient(baseUrl: 'http://test'));

  final List<String> requestedIds = [];

  @override
  Future<Exercise> getExercise(String id) async {
    requestedIds.add(id);
    return Exercise(id: id, name: 'Ejercicio', hasVideo: true);
  }
}

class _FakeTrainingPlansNotifier extends TrainingPlansNotifier {
  _FakeTrainingPlansNotifier(this.plans);

  final List<TrainingPlan> plans;

  @override
  Future<List<TrainingPlan>> build() async => plans;
}

class _FakeWorkoutHistoryRepository implements WorkoutHistoryRepository {
  final List<WorkoutHistoryEntry> recordedEntries = [];

  @override
  Future<List<WorkoutHistoryEntry>> getWorkoutHistory() async =>
      recordedEntries;

  @override
  Future<WorkoutHistoryEntry> recordActivity(
    WorkoutHistoryEntry entry,
  ) async {
    recordedEntries.add(entry);
    return entry;
  }

  @override
  Future<List<WorkoutHistoryEntry>> searchWorkoutHistory({
    DateTime? from,
    DateTime? to,
    List<String> trainingIds = const [],
    List<String> exerciseIds = const [],
    String? userId,
  }) async =>
      recordedEntries;

  @override
  Future<WorkoutHistoryFilterOptions> getFilterOptions({String? userId}) async =>
      const WorkoutHistoryFilterOptions();
}
