import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ap_training/core/client/api_client.dart';
import 'package:ap_training/features/auth/providers/auth_provider.dart';
import 'package:ap_training/features/exercise/models/exercise_catalogs.dart';
import 'package:ap_training/features/exercise/models/exercise_video_source.dart';
import 'package:ap_training/features/exercise/providers/catalogs_provider.dart';
import 'package:ap_training/features/exercise/utils/youtube_video_id.dart';
import 'package:ap_training/features/exercise/screens/exercise_editor_screen.dart';
import 'package:ap_training/features/exercise/screens/exercises_screen.dart';
import 'package:ap_training/features/workout/models/training.dart';
import 'package:ap_training/features/workout/providers/trainings_provider.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

void main() {
  testWidgets('editing preserves IDs missing from the loaded catalogs',
      (tester) async {
    final apiClient = _RecordingApiClient();
    final router = GoRouter(
      initialLocation: '/exercises',
      routes: [
        GoRoute(
          path: '/exercises',
          builder: (_, __) => const Scaffold(body: Text('Lista de ejercicios')),
          routes: [
            GoRoute(
              path: ':exerciseId/edit',
              builder: (_, state) => ExerciseEditorScreen(
                exerciseId: state.pathParameters['exerciseId'],
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          catalogsProvider.overrideWith(
            () => _TestCatalogsNotifier(_catalogs),
          ),
          exerciseYoutubePlayerBuilderProvider.overrideWithValue(
            ({required videoId, required vertical, required autoPlay}) =>
                Text('youtube:$videoId:$vertical:$autoPlay'),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    unawaited(router.push('/exercises/exercise-id/edit'));
    await tester.pumpAndSettle();

    final videoSourceSelector = find.byType(
      DropdownButtonFormField<ExerciseVideoSource>,
    );
    await tester.ensureVisible(videoSourceSelector);
    await tester.tap(videoSourceSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enlace de YouTube').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'URL de YouTube',
      ),
      'https://youtu.be/dQw4w9WgXcQ',
    );

    await tester.pump();
    expect(find.text('youtube:dQw4w9WgXcQ:false:false'), findsOneWidget);

    final saveButton = find.text('Guardar cambios');
    await tester.scrollUntilVisible(
      saveButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(apiClient.sentData?['exerciseTypeId'], 7);
    expect(apiClient.sentData?['movementPatternId'], 3);
    expect(apiClient.sentData?['videoSource'], 'youtube');
    expect(apiClient.sentData?['youtubeUrl'], 'https://youtu.be/dQw4w9WgXcQ');
    expect(find.text('Lista de ejercicios'), findsOneWidget);
  });


  testWidgets('exercise filters show video and training toggles without Todos',
      (tester) async {
    final apiClient = _RecordingApiClient();
    await _showExercisesScreen(tester, apiClient);

    expect(find.text('Todos'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Con vídeo'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Con entreno'), findsOneWidget);
    expect(find.text('Grupo muscular'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Con entreno'));
    await tester.pumpAndSettle();
    expect(find.text('Sin resultados'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Con entreno'));
    await tester.pumpAndSettle();
    expect(find.text('Sentadilla'), findsOneWidget);
  });

  testWidgets('limpiar resets exercise filters', (tester) async {
    final apiClient = _RecordingApiClient();
    await _showExercisesScreen(tester, apiClient);

    expect(find.text('Limpiar'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'Con entreno'));
    await tester.pumpAndSettle();
    expect(find.text('Sin resultados'), findsOneWidget);

    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();

    expect(find.text('Limpiar'), findsNothing);
    expect(find.text('Sentadilla'), findsOneWidget);
  });

  testWidgets('list request errors are not shown as an empty list',
      (tester) async {
    final apiClient = _RecordingApiClient()..exerciseListStatusCode = 503;
    await _showExercisesScreen(tester, apiClient);

    expect(find.text('No se pudieron cargar los ejercicios'), findsOneWidget);
    expect(find.text('Sin resultados'), findsNothing);

    apiClient.exerciseListStatusCode = 200;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Sentadilla'), findsOneWidget);
    expect(apiClient.exerciseListCalls, 2);
  });

  testWidgets('failed delete restores the exercise', (tester) async {
    final apiClient = _RecordingApiClient()..deleteStatusCode = 500;
    await _showExercisesScreen(tester, apiClient);

    await _deleteVisibleExercise(tester);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Sentadilla'), findsOneWidget);
    expect(find.text('No se ha podido eliminar el ejercicio'), findsOneWidget);
    expect(apiClient.deleteCalls, 1);
  });

  testWidgets(
      'shows the server reason when an exercise is assigned to a training',
      (tester) async {
    final apiClient = _RecordingApiClient()
      ..deleteStatusCode = 400
      ..deleteResponseBody = jsonEncode({
        'error':
            'No se puede eliminar el ejercicio porque está asignado al entreno "Entreno push"',
      });
    await _showExercisesScreen(tester, apiClient);

    await _deleteVisibleExercise(tester);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No se puede eliminar el ejercicio porque está asignado al entreno "Entreno push"',
      ),
      findsOneWidget,
    );
    expect(find.text('Sentadilla'), findsOneWidget);
  });

  testWidgets('successful delete keeps the exercise removed', (tester) async {
    final apiClient = _RecordingApiClient()..deleteStatusCode = 200;
    await _showExercisesScreen(tester, apiClient);

    await _deleteVisibleExercise(tester);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Sentadilla'), findsNothing);
    expect(find.text('Sin resultados'), findsOneWidget);
    expect(apiClient.deleteCalls, 1);
  });

  testWidgets('video initialization failure offers a retry', (tester) async {
    final failingController = _FailingVideoController();
    await tester.pumpWidget(
      _editorApp('exercise-with-video', [
        exerciseVideoControllerFactoryProvider
            .overrideWithValue((_) => failingController),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar el vídeo'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(failingController.wasDisposed, isTrue);
  });

  testWidgets('does not update state after disposal during initialization',
      (tester) async {
    final pendingController = _PendingVideoController();
    await tester.pumpWidget(
      _editorApp('exercise-with-video', [
        exerciseVideoControllerFactoryProvider
            .overrideWithValue((_) => pendingController),
      ]),
    );
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    pendingController.initialization.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(pendingController.wasDisposed, isTrue);
  });

  testWidgets('rapidly opening another exercise discards stale video loading',
      (tester) async {
    final firstController = _PendingVideoController();
    final secondController = _PendingVideoController();
    var controllerIndex = 0;
    final controllers = [firstController, secondController];
    final overrides = [
      exerciseVideoControllerFactoryProvider.overrideWithValue(
        (_) => controllers[controllerIndex++],
      ),
    ];

    await tester.pumpWidget(_editorApp('first-exercise', overrides));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(_editorApp('second-exercise', overrides));
    await tester.pump();
    await tester.pump();

    firstController.initialization.complete();
    secondController.initialization.complete();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(firstController.wasDisposed, isTrue);
    expect(firstController.playCalls, 0);
    expect(secondController.playCalls, 1);
  });

  testWidgets('saved YouTube Short opens vertical and autoplays',
      (tester) async {
    await tester.pumpWidget(
      _editorApp(
        'short-exercise',
        const [],
        videoUrl: 'https://www.youtube.com/shorts/dQw4w9WgXcQ',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('youtube:dQw4w9WgXcQ:true:true'), findsOneWidget);
  });

  test('detects vertical YouTube Shorts URLs', () {
    expect(
      isYoutubeShortsUrl('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
      isTrue,
    );
    expect(isYoutubeShortsUrl('https://youtu.be/dQw4w9WgXcQ'), isFalse);
    expect(
      isYoutubeShortsUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      isFalse,
    );
    expect(isYoutubeShortsUrl(null), isFalse);
  });
}

Widget _editorApp(
  String id,
  List<Override> overrides, {
  String? videoUrl,
}) =>
    ProviderScope(
      key: ValueKey(id),
      overrides: [
        apiClientProvider.overrideWithValue(
          _RecordingApiClient()
            ..videoUrl = videoUrl ?? 'https://example.test/$id.mp4',
        ),
        catalogsProvider.overrideWith(() => _TestCatalogsNotifier(_catalogs)),
        exerciseYoutubePlayerBuilderProvider.overrideWithValue(
          ({required videoId, required vertical, required autoPlay}) =>
              Text('youtube:$videoId:$vertical:$autoPlay'),
        ),
        ...overrides,
      ],
      child: MaterialApp(home: ExerciseEditorScreen(exerciseId: id)),
    );

Future<void> _showExercisesScreen(
  WidgetTester tester,
  _RecordingApiClient apiClient,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        trainingsProvider.overrideWith(() => _EmptyTrainingsNotifier()),
      ],
      child: const MaterialApp(home: ExercisesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _EmptyTrainingsNotifier extends TrainingsNotifier {
  @override
  Future<List<Training>> build() async => const [];
}

Future<void> _deleteVisibleExercise(WidgetTester tester) async {
  await tester.drag(find.text('Sentadilla'), const Offset(-400, 0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Borrar'));
  await tester.pumpAndSettle();
}

const _catalogs = ExerciseCatalogs(
  exerciseTypes: [],
  movementPatterns: [],
  muscleGroups: [],
  equipment: [],
);

class _TestCatalogsNotifier extends CatalogsNotifier {
  _TestCatalogsNotifier(this.catalogs);

  final ExerciseCatalogs catalogs;

  @override
  Future<ExerciseCatalogs> build() async => catalogs;
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(baseUrl: 'http://test');

  Map<String, dynamic>? sentData;
  int exerciseListStatusCode = 200;
  int exerciseListCalls = 0;
  int deleteStatusCode = 200;
  String deleteResponseBody = '';
  int deleteCalls = 0;
  String? videoUrl;

  @override
  Future<http.Response> get(String path) async {
    if (path.startsWith('/exercises/')) {
      return http.Response(
        jsonEncode({
          'id': path.substring('/exercises/'.length),
          'name': 'Press de banca',
          'videoUrl': videoUrl,
          'exerciseTypeId': 7,
          'exerciseTypeName': 'Fuerza',
          'movementPatternId': 3,
          'movementPatternName': 'Empuje',
        }),
        200,
      );
    }
    if (path == '/exercises') {
      exerciseListCalls++;
      final body = exerciseListStatusCode == 200
          ? jsonEncode([
              {'id': 'exercise-id', 'name': 'Sentadilla', 'hasVideo': false},
            ])
          : '{"error":"unavailable"}';
      return http.Response(body, exerciseListStatusCode);
    }
    return http.Response('[]', 200);
  }

  @override
  Future<http.Response> delete(String path) async {
    deleteCalls++;
    return http.Response(deleteResponseBody, deleteStatusCode);
  }

  @override
  Future<http.Response> putMultipart(
    String path, {
    required Map<String, String> fields,
    required Future<List<http.MultipartFile>> Function() filesBuilder,
  }) async {
    final files = await filesBuilder();
    final bytes = await files.first.finalize().toBytes();
    sentData = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return http.Response('{}', 200);
  }
}

class _FailingVideoController extends VideoPlayerController {
  _FailingVideoController()
      : super.networkUrl(Uri.parse('https://example.test/video.mp4'));

  bool wasDisposed = false;

  @override
  Future<void> initialize() async {
    throw StateError('Video initialization failed');
  }

  @override
  Future<void> dispose() async {
    wasDisposed = true;
    try {
      await super.dispose();
    } catch (_) {}
  }
}

class _PendingVideoController extends VideoPlayerController {
  _PendingVideoController()
      : super.networkUrl(Uri.parse('https://example.test/video.mp4'));

  final Completer<void> initialization = Completer<void>();
  bool wasDisposed = false;
  int playCalls = 0;

  @override
  Future<void> initialize() => initialization.future;

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {
    wasDisposed = true;
    try {
      await super.dispose();
    } catch (_) {}
  }
}
