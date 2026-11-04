import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/features/workout/models/training.dart';
import 'package:ap_training/features/workout/providers/trainings_provider.dart';
import 'package:ap_training/features/workout/screens/training_editor_screen.dart';

void main() {
  testWidgets('saving focuses and scrolls to the first invalid exercise field',
      (tester) async {
    final training = Training(
      id: 'training-1',
      name: 'Día A',
      exercises: [
        for (var index = 0; index < 5; index++)
          TrainingExercise(
            exerciseId: 'exercise-$index',
            exerciseName: 'Ejercicio $index',
            repetitions: 10,
            repetitionType: TrainingRepetitionType.fixed,
            series: 3,
            rpe: 8,
            measurementUnit: TrainingLoadUnit.kg,
            load: 10,
            orderIndex: index,
          ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingsProvider.overrideWith(
            () => _EditorTrainingsNotifier(training),
          ),
        ],
        child: const MaterialApp(
          home: TrainingEditorScreen(trainingId: 'training-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lastExercise = find.text('Ejercicio 4');
    await tester.ensureVisible(lastExercise);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Desplegar ejercicio').last);
    await tester.pumpAndSettle();
    expect(find.text('Series'), findsOneWidget);

    final seriesField = find.byWidgetPredicate(
      (widget) => widget is EditableText && widget.controller.text == '3',
    );
    await tester.enterText(seriesField, '');
    await tester.tap(find.byTooltip('Plegar ejercicio'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Obligatorio'), findsOneWidget);
    final focusedEditableText = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .firstWhere((field) => field.focusNode.hasFocus);
    final focusedField = find.byWidget(focusedEditableText);
    expect(focusedEditableText.controller.text, isEmpty);
    expect(tester.getTopLeft(focusedField).dy, greaterThanOrEqualTo(0));
  });
}

class _EditorTrainingsNotifier extends TrainingsNotifier {
  _EditorTrainingsNotifier(this.training);

  final Training training;

  @override
  Future<List<Training>> build() async => [training];

  @override
  Future<Training> getTraining(String id) async => training;
}
