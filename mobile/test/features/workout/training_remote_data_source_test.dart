import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/core/client/api_client.dart';
import 'package:ap_training/features/workout/data/training_remote_data_source.dart';
import 'package:http/http.dart' as http;

void main() {
  test('delete exposes the server reason when a training is assigned to a plan',
      () async {
    final client = _FakeApiClient()
      ..response = http.Response(
        jsonEncode({
          'error':
              'No se puede eliminar el entrenamiento porque está asignado a la planificación "Plan de fuerza"',
        }),
        400,
      );
    final dataSource = TrainingRemoteDataSource(client);

    try {
      await dataSource.deleteTraining('training-1');
      fail('Expected the delete request to fail');
    } on TrainingApiException catch (error) {
      expect(error.message,
          'No se puede eliminar el entrenamiento porque está asignado a la planificación "Plan de fuerza"');
    }
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://test');

  http.Response response = http.Response('', 200);

  @override
  Future<http.Response> delete(String path) async => response;
}
