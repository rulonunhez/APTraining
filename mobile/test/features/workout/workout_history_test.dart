import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/core/client/api_client.dart';
import 'package:ap_training/features/workout/data/workout_history_remote_data_source.dart';
import 'package:ap_training/features/workout/models/training.dart';
import 'package:ap_training/features/workout/models/workout_history_entry.dart';
import 'package:http/http.dart' as http;

void main() {
  test('history snapshot copies prescription values without per-set data', () {
    const training = Training(
      id: 'training-1',
      name: 'Rutina A',
      exercises: [
        TrainingExercise(
          exerciseId: 'exercise-1',
          exerciseName: 'Press banca',
          repetitions: 8,
          repetitionsMax: 10,
          repetitionType: TrainingRepetitionType.range,
          series: 4,
          rpe: 8,
          measurementUnit: TrainingLoadUnit.kg,
          load: 52.5,
          orderIndex: 0,
        ),
      ],
    );

    final snapshot = WorkoutHistoryEntry.fromTraining(training);
    final json = snapshot.toJson();
    final exercise = (json['exercises'] as List).single as Map<String, dynamic>;

    expect(json['trainingId'], 'training-1');
    expect(json['trainingName'], 'Rutina A');
    expect(exercise['exerciseName'], 'Press banca');
    expect(exercise['series'], 4);
    expect(exercise['repetitions'], 8);
    expect(exercise['repetitionsMax'], 10);
    expect(exercise['repetitionType'], 'RANGE');
    expect(exercise['load'], 52.5);
    expect(exercise['sets'], isEmpty);
  });

  test('remote data source posts and reads workout history', () async {
    final client = _FakeApiClient();
    final dataSource = WorkoutHistoryRemoteDataSource(client);
    const responseEntry = {
      'id': 'history-1',
      'trainingId': 'training-1',
      'trainingName': 'Rutina A',
      'completedAt': '2026-10-06T09:00:00Z',
      'exercises': [],
    };

    client.response = http.Response(jsonEncode(responseEntry), 200);
    final recorded = await dataSource.recordActivity(
      WorkoutHistoryEntry(
        trainingId: 'training-1',
        trainingName: 'Rutina A',
        exercises: const [],
      ),
    );
    expect(client.postPath, '/workout-history');
    expect(client.postBody?['trainingId'], 'training-1');
    expect(recorded.id, 'history-1');
    expect(recorded.completedAt?.isUtc, isTrue);

    client.response = http.Response(jsonEncode([responseEntry]), 200);
    final entries = await dataSource.getWorkoutHistory();
    expect(client.getPath, '/workout-history');
    expect(entries.single.trainingName, 'Rutina A');
  });

  test('remote data source reports an unsuccessful save', () async {
    final client = _FakeApiClient()
      ..response = http.Response('{"error":"unavailable"}', 503);
    final dataSource = WorkoutHistoryRemoteDataSource(client);

    await expectLater(
      dataSource.recordActivity(
        WorkoutHistoryEntry(
          trainingId: 'training-1',
          trainingName: 'Rutina A',
          exercises: const [],
        ),
      ),
      throwsA(isA<WorkoutHistoryApiException>()),
    );
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://test');

  http.Response response = http.Response('', 200);
  String? getPath;
  String? postPath;
  Map<String, dynamic>? postBody;

  @override
  Future<http.Response> get(String path) async {
    getPath = path;
    return response;
  }

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    postPath = path;
    postBody = body;
    return response;
  }
}
