import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/features/exercise/models/exercise.dart';
import 'package:ap_training/features/exercise/providers/exercises_provider.dart';
import 'package:ap_training/features/planning/models/training_plan.dart';
import 'package:ap_training/features/planning/providers/training_plans_provider.dart';
import 'package:ap_training/features/workout/data/training_remote_data_source.dart';
import 'package:ap_training/features/workout/models/training.dart';
import 'package:ap_training/features/workout/providers/trainings_provider.dart';
import 'package:ap_training/features/workout/screens/workouts_screen.dart';

void main() {
  testWidgets('planned toggle shows only trainings assigned to a plan',
      (tester) async {
    final notifier = _WorkoutsNotifier([
      const Training(id: 'training-1', name: 'Entrenamiento A'),
      const Training(id: 'training-2', name: 'Entrenamiento B'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingsProvider.overrideWith(() => notifier),
          exercisesProvider.overrideWith(() => _ExercisesNotifier()),
          trainingPlansProvider.overrideWith(() => _PlansNotifier([
                const TrainingPlan(
                  name: 'Plan de fuerza',
                  workouts: [
                    TrainingPlanWorkout(
                      trainingId: 'training-2',
                      schedules: [],
                    ),
                  ],
                ),
              ])),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Planificados'));
    await tester.pumpAndSettle();

    expect(find.text('Entrenamiento A'), findsNothing);
    expect(find.text('Entrenamiento B'), findsOneWidget);
  });

  testWidgets('swiping a training reveals delete and removes it after confirm',
      (tester) async {
    final notifier = _WorkoutsNotifier([
      const Training(id: 'training-1', name: 'Entrenamiento A'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingsProvider.overrideWith(() => notifier),
          exercisesProvider.overrideWith(() => _ExercisesNotifier()),
          trainingPlansProvider.overrideWith(() => _PlansNotifier(const [])),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Crear'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.drag(find.text('Entrenamiento A'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Borrar'), findsOneWidget);

    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(notifier.deletedIds, ['training-1']);
    expect(find.text('Entrenamiento A'), findsNothing);
  });

  testWidgets('shows the server reason when a training belongs to a plan',
      (tester) async {
    final notifier = _WorkoutsNotifier([
      const Training(id: 'training-1', name: 'Entrenamiento A'),
    ])
      ..deleteError = const TrainingApiException(
        '/trainings/training-1',
        400,
        message:
            'No se puede eliminar el entrenamiento porque está asignado a la planificación "Plan de fuerza"',
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingsProvider.overrideWith(() => notifier),
          exercisesProvider.overrideWith(() => _ExercisesNotifier()),
          trainingPlansProvider.overrideWith(() => _PlansNotifier(const [])),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.text('Entrenamiento A'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No se puede eliminar el entrenamiento porque está asignado a la planificación "Plan de fuerza"',
      ),
      findsOneWidget,
    );
    expect(find.text('Entrenamiento A'), findsOneWidget);
  });
}

class _ExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => [];
}

class _PlansNotifier extends TrainingPlansNotifier {
  _PlansNotifier(this.plans);

  final List<TrainingPlan> plans;

  @override
  Future<List<TrainingPlan>> build() async => plans;
}

class _WorkoutsNotifier extends TrainingsNotifier {
  _WorkoutsNotifier(this.trainings);

  final List<Training> trainings;
  final deletedIds = <String>[];
  Exception? deleteError;

  @override
  Future<List<Training>> build() async => trainings;

  @override
  Future<void> deleteTraining(String id) async {
    if (deleteError != null) throw deleteError!;
    deletedIds.add(id);
    state = AsyncData(
      state.requireValue.where((training) => training.id != id).toList(),
    );
  }
}
