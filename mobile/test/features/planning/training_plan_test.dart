import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/core/client/api_client.dart';
import 'package:ap_training/features/planning/data/training_plan_remote_data_source.dart';
import 'package:ap_training/features/planning/models/training_plan.dart';
import 'package:http/http.dart' as http;

void main() {
  test('training plan serializes weekly schedules using backend values', () {
    final plan = TrainingPlan(
      name: 'Fuerza',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 12, 5),
      workouts: const [
        TrainingPlanWorkout(
          trainingId: 'training-1',
          orderIndex: 0,
          schedules: [
            TrainingPlanSchedule(
              dayOfWeek: TrainingPlanDay.monday,
              startMinuteOfDay: 19 * 60,
              endMinuteOfDay: 20 * 60,
            ),
            TrainingPlanSchedule(dayOfWeek: TrainingPlanDay.friday),
          ],
        ),
      ],
    );

    final json = plan.toJson();
    final restored = TrainingPlan.fromJson({
      ...json,
      'id': 'plan-1',
      'workouts': [
        {
          ...((json['workouts'] as List).single as Map<String, dynamic>),
          'trainingName': 'Día A',
        },
      ],
    });

    expect(json['startDate'], '2026-10-05');
    final workouts = json['workouts'] as List<dynamic>;
    final workout = workouts.single as Map<String, dynamic>;
    final schedules = workout['schedules'] as List<dynamic>;
    expect(schedules[0]['dayOfWeek'], 'MONDAY');
    expect(schedules[0]['startTime'], '19:00:00');
    expect(schedules[0]['endTime'], '20:00:00');
    expect(schedules[1]['startTime'], isNull);
    expect(restored.id, 'plan-1');
    expect(restored.workouts.single.trainingName, 'Día A');
    expect(restored.workouts.single.schedules.last.dayOfWeek,
        TrainingPlanDay.friday);
  });

  test('plans without validity dates are active indefinitely', () {
    final plan = TrainingPlan(
      name: 'Rutina continua',
      workouts: const [
        TrainingPlanWorkout(
          trainingId: 'training-1',
          schedules: [
            TrainingPlanSchedule(dayOfWeek: TrainingPlanDay.monday),
          ],
        ),
      ],
    );

    expect(plan.isActiveOn(DateTime(2026, 10, 5)), isTrue);
    expect(plan.workouts.single.isScheduledOn(DateTime(2026, 10, 5)), isTrue);
    expect(plan.workouts.single.isScheduledOn(DateTime(2026, 10, 6)), isFalse);
    expect(plan.toJson()['startDate'], isNull);
    expect(plan.toJson()['endDate'], isNull);

    final restored = TrainingPlan.fromJson({
      ...plan.toJson(),
      'id': 'plan-1',
    });
    expect(restored.startDate, isNull);
    expect(restored.endDate, isNull);
  });

  test('dated plans include both validity boundary dates', () {
    final plan = TrainingPlan(
      name: 'Rutina temporal',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 11),
    );

    expect(plan.isActiveOn(DateTime(2026, 10, 4)), isFalse);
    expect(plan.isActiveOn(DateTime(2026, 10, 5)), isTrue);
    expect(plan.isActiveOn(DateTime(2026, 10, 11)), isTrue);
    expect(plan.isActiveOn(DateTime(2026, 10, 12)), isFalse);
  });

  test('remote data source uses training plan CRUD endpoints', () async {
    final client = _FakeApiClient();
    final dataSource = TrainingPlanRemoteDataSource(client);
    const responsePlan = {
      'id': 'plan-1',
      'name': 'Fuerza',
      'startDate': '2026-10-05',
      'endDate': '2026-12-05',
      'workouts': [],
    };

    client.response = http.Response(jsonEncode([responsePlan]), 200);
    expect((await dataSource.getTrainingPlans()).single.id, 'plan-1');
    expect(client.getPath, '/training-plans');

    client.response = http.Response(jsonEncode(responsePlan), 200);
    expect((await dataSource.getTrainingPlan('plan-1')).name, 'Fuerza');
    expect(client.getPath, '/training-plans/plan-1');

    client.response = http.Response(jsonEncode(responsePlan), 200);
    await dataSource.createTrainingPlan(_plan());
    expect(client.postPath, '/training-plans');
    expect(client.postBody?['name'], 'Fuerza');

    client.response = http.Response(jsonEncode(responsePlan), 200);
    await dataSource.updateTrainingPlan('plan-1', _plan());
    expect(client.putPath, '/training-plans/plan-1');

    client.response = http.Response('', 204);
    await dataSource.deleteTrainingPlan('plan-1');
    expect(client.deletePath, '/training-plans/plan-1');
  });

  test('remote data source reports unsuccessful plan requests', () async {
    final client = _FakeApiClient()
      ..response = http.Response('{"error":"unavailable"}', 503);
    final dataSource = TrainingPlanRemoteDataSource(client);

    await expectLater(
      dataSource.getTrainingPlans(),
      throwsA(isA<TrainingPlanApiException>()),
    );
  });
}

TrainingPlan _plan() => TrainingPlan(
      name: 'Fuerza',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 12, 5),
    );

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://test');

  http.Response response = http.Response('', 200);
  String? getPath;
  String? postPath;
  Map<String, dynamic>? postBody;
  String? putPath;
  String? deletePath;

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

  @override
  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    putPath = path;
    return response;
  }

  @override
  Future<http.Response> delete(String path) async {
    deletePath = path;
    return response;
  }
}
