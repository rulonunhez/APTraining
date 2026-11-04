import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/core/client/api_client.dart';
import 'package:ap_training/features/exercise/data/exercise_remote_data_source.dart';
import 'package:ap_training/features/exercise/models/exercise_write_request.dart';
import 'package:ap_training/features/exercise/models/exercise_video_source.dart';
import 'package:http/http.dart' as http;

void main() {
  test('an empty successful list is distinct from an HTTP failure', () async {
    final client = _FakeApiClient()..response = http.Response('[]', 200);
    final dataSource = ExerciseRemoteDataSource(client);

    expect(await dataSource.getExercises(), isEmpty);

    client.response = http.Response('{"error":"unavailable"}', 503);
    await expectLater(
      dataSource.getExercises(),
      throwsA(isA<ExerciseApiException>()),
    );
  });

  test('delete rejects unsuccessful HTTP responses', () async {
    final client = _FakeApiClient()
      ..response = http.Response(
        '{"error":"No se puede eliminar el ejercicio porque está asignado al entreno \\"Entreno push\\""}',
        400,
      );
    final dataSource = ExerciseRemoteDataSource(client);

    try {
      await dataSource.deleteExercise('exercise-id');
      fail('Expected the delete request to fail');
    } on ExerciseApiException catch (error) {
      expect(error.message,
          'No se puede eliminar el ejercicio porque está asignado al entreno "Entreno push"');
    }
  });

  test('preserves backend error details and request correlation ID', () async {
    final client = _FakeApiClient()
      ..response = http.Response(
        '{"error":"No se pudo completar la operación de almacenamiento","requestId":"req-123"}',
        502,
      );
    final dataSource = ExerciseRemoteDataSource(client);

    try {
      await dataSource.createExercise(
        const ExerciseWriteRequest(name: 'Sentadilla'),
      );
      fail('Expected the create request to fail');
    } on ExerciseApiException catch (error) {
      expect(error.statusCode, 502);
      expect(error.message, 'No se pudo completar la operación de almacenamiento');
      expect(error.requestId, 'req-123');
      expect(error.toString(), contains('req-123'));
    }
  });

  test('create sends the backend JSON contract as multipart data', () async {
    final client = _FakeApiClient()..response = http.Response('{}', 200);
    final dataSource = ExerciseRemoteDataSource(client);
    const request = ExerciseWriteRequest(
      name: 'Sentadilla',
      exerciseTypeId: 7,
      movementPatternId: 3,
      primaryMuscleGroupIds: [1],
      secondaryMuscleGroupIds: [2],
      equipmentIds: [4],
      explanation: 'Controla el descenso',
      videoSource: ExerciseVideoSource.youtube,
      youtubeUrl: 'https://youtu.be/dQw4w9WgXcQ',
    );

    await dataSource.createExercise(request);

    expect(client.multipartPath, '/exercises');
    final part = client.multipartFiles!.single;
    expect(part.field, 'data');
    final bytes = await part.finalize().toBytes();
    expect(jsonDecode(utf8.decode(bytes)), request.toJson());
  });
  test('uploads the video directly via presigned URL and sends only its key',
      () async {
    final client = _FakeApiClient()..response = http.Response('{}', 200);
    client.postResponse = http.Response(
      jsonEncode({
        'uploadUrl': 'https://bucket.s3.amazonaws.com/signed',
        'key': 'exercises/u1/abc',
        'contentType': 'video/mp4',
      }),
      200,
    );
    final dataSource = ExerciseRemoteDataSource(client);
    final dir = Directory.systemTemp.createTempSync('video_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final video = File('${dir.path}/press.mp4')..writeAsBytesSync([1, 2, 3]);

    await dataSource.createExercise(
      const ExerciseWriteRequest(
        name: 'Press',
        videoSource: ExerciseVideoSource.upload,
      ),
      video: video,
    );

    expect(client.postPath, '/exercises/video-upload-url');
    expect(client.postBody, {'contentType': 'video/mp4', 'sizeBytes': 3});
    expect(client.uploadedUrl, 'https://bucket.s3.amazonaws.com/signed');
    final part = client.multipartFiles!.single;
    expect(part.field, 'data');
    final json = jsonDecode(utf8.decode(await part.finalize().toBytes()))
        as Map<String, dynamic>;
    expect(json['uploadedVideoKey'], 'exercises/u1/abc');
    expect(json['uploadedVideoName'], 'press.mp4');
  });

  test('videoContentType maps common extensions', () {
    expect(videoContentType('a.MOV'), 'video/quicktime');
    expect(videoContentType('a.mp4'), 'video/mp4');
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://test');

  http.Response response = http.Response('', 200);
  http.Response postResponse = http.Response('{}', 200);
  String? multipartPath;
  List<http.MultipartFile>? multipartFiles;
  String? postPath;
  Map<String, dynamic>? postBody;
  String? uploadedUrl;

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    postPath = path;
    postBody = body;
    return postResponse;
  }

  @override
  Future<http.Response> putFileToUrl(
    String url,
    File file, {
    required String contentType,
  }) async {
    uploadedUrl = url;
    return http.Response('', 200);
  }

  @override
  Future<http.Response> get(String path) async => response;

  @override
  Future<http.Response> delete(String path) async => response;

  @override
  Future<http.Response> postMultipart(
    String path, {
    required Map<String, String> fields,
    required Future<List<http.MultipartFile>> Function() filesBuilder,
  }) async {
    multipartPath = path;
    multipartFiles = await filesBuilder();
    return response;
  }
}
