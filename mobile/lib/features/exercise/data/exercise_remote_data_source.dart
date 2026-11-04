import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/client/api_client.dart';
import '../models/exercise.dart';
import '../models/exercise_catalogs.dart';
import '../models/exercise_write_request.dart';

const maxVideoSizeBytes = 100 * 1024 * 1024;

String videoContentType(String path) {
  final extension = path.split('.').last.toLowerCase();
  return switch (extension) {
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    '3gp' => 'video/3gpp',
    'm4v' => 'video/x-m4v',
    'mkv' => 'video/x-matroska',
    _ => 'video/mp4',
  };
}

class VideoTooLargeException implements Exception {
  final int maxBytes;

  const VideoTooLargeException(this.maxBytes);

  String get message =>
      'El vídeo supera el tamaño máximo de ${maxBytes ~/ (1024 * 1024)} MB';

  @override
  String toString() => message;
}

class ExerciseApiException implements Exception {
  final String path;
  final int statusCode;
  final String? message;
  final String? requestId;

  const ExerciseApiException(
    this.path,
    this.statusCode, {
    this.message,
    this.requestId,
  });

  @override
  String toString() =>
      'Request to $path failed with status $statusCode'
      '${requestId == null ? '' : ' (requestId: $requestId)'}'
      '${message == null ? '' : ': $message'}';
}

class ExerciseRemoteDataSource {
  final ApiClient apiClient;

  const ExerciseRemoteDataSource(this.apiClient);

  Future<List<Exercise>> getExercises() async {
    const path = '/exercises';
    final response = await apiClient.get(path);
    _requireSuccess(path, response);

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((json) => Exercise.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Exercise> getExercise(String id) async {
    final path = '/exercises/$id';
    final response = await apiClient.get(path);
    _requireSuccess(path, response);
    return Exercise.fromDetailJson(response.body);
  }

  Future<ExerciseCatalogs> getCatalogs() async {
    const paths = [
      '/exercise-types',
      '/movement-patterns',
      '/muscle-groups',
      '/equipment',
    ];
    final responses = await Future.wait(paths.map(apiClient.get));

    for (var index = 0; index < responses.length; index++) {
      _requireSuccess(paths[index], responses[index]);
    }

    return ExerciseCatalogs(
      exerciseTypes: _parseCatalogs(responses[0]),
      movementPatterns: _parseCatalogs(responses[1]),
      muscleGroups: _parseCatalogs(responses[2]),
      equipment: _parseCatalogs(responses[3]),
    );
  }

  Future<void> createExercise(
    ExerciseWriteRequest request, {
    File? video,
  }) async {
    const path = '/exercises';
    final finalRequest = await _withUploadedVideo(request, video);
    final response = await apiClient.postMultipart(
      path,
      fields: const {},
      filesBuilder: () => _multipartFiles(finalRequest),
    );
    _requireSuccess(path, response);
  }

  Future<void> updateExercise(
    String id,
    ExerciseWriteRequest request, {
    File? video,
  }) async {
    final path = '/exercises/$id';
    final finalRequest = await _withUploadedVideo(request, video);
    final response = await apiClient.putMultipart(
      path,
      fields: const {},
      filesBuilder: () => _multipartFiles(finalRequest),
    );
    _requireSuccess(path, response);
  }

  Future<void> deleteExercise(String id) async {
    final path = '/exercises/$id';
    final response = await apiClient.delete(path);
    _requireSuccess(path, response);
  }

  // El vídeo se sube directo a S3 con una URL prefirmada; el backend solo
  // recibe la clave del objeto, evitando los límites de tamaño y tiempo
  // de API Gateway.
  Future<ExerciseWriteRequest> _withUploadedVideo(
    ExerciseWriteRequest request,
    File? video,
  ) async {
    if (video == null) return request;

    final size = await video.length();
    if (size > maxVideoSizeBytes) {
      throw const VideoTooLargeException(maxVideoSizeBytes);
    }
    final contentType = videoContentType(video.path);

    const urlPath = '/exercises/video-upload-url';
    final urlResponse = await apiClient.post(urlPath, {
      'contentType': contentType,
      'sizeBytes': size,
    });
    _requireSuccess(urlPath, urlResponse);
    final data = jsonDecode(urlResponse.body) as Map<String, dynamic>;

    final uploadResponse = await apiClient.putFileToUrl(
      data['uploadUrl'] as String,
      video,
      contentType: data['contentType'] as String? ?? contentType,
    );
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw ExerciseApiException(
        'direct-video-upload',
        uploadResponse.statusCode,
        message: 'No se pudo subir el vídeo',
      );
    }

    return request.withUploadedVideo(
      data['key'] as String,
      video.uri.pathSegments.last,
    );
  }

  Future<List<http.MultipartFile>> _multipartFiles(
    ExerciseWriteRequest request,
  ) async {
    return [
      http.MultipartFile.fromString(
        'data',
        jsonEncode(request.toJson()),
        contentType: MediaType('application', 'json'),
      ),
    ];
  }

  List<CatalogItem> _parseCatalogs(http.Response response) {
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((json) => CatalogItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  void _requireSuccess(String path, http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ExerciseApiException(
        path,
        response.statusCode,
        message: _errorMessage(response.body),
        requestId: _requestId(response.body),
      );
    }
  }

  String? _requestId(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final requestId = decoded['requestId'];
        if (requestId is String && requestId.trim().isNotEmpty) {
          return requestId.trim();
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  String? _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
