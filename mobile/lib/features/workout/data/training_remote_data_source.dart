import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/client/api_client.dart';
import '../models/training.dart';

class TrainingApiException implements Exception {
  const TrainingApiException(this.path, this.statusCode, {this.message});

  final String path;
  final int statusCode;
  final String? message;

  @override
  String toString() => 'Request to $path failed with status $statusCode';
}

class TrainingRemoteDataSource {
  const TrainingRemoteDataSource(this.apiClient);

  final ApiClient apiClient;

  Future<List<Training>> getTrainings() async {
    const path = '/trainings';
    final response = await apiClient.get(path);
    _requireSuccess(path, response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => Training.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Training> getTraining(String id) async {
    final path = '/trainings/$id';
    final response = await apiClient.get(path);
    _requireSuccess(path, response);
    return Training.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Training> createTraining(Training training) async {
    const path = '/trainings';
    final response = await apiClient.post(path, training.toJson());
    _requireSuccess(path, response);
    return Training.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Training> updateTraining(String id, Training training) async {
    final path = '/trainings/$id';
    final response = await apiClient.put(path, training.toJson());
    _requireSuccess(path, response);
    return Training.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteTraining(String id) async {
    final path = '/trainings/$id';
    final response = await apiClient.delete(path);
    _requireSuccess(path, response);
  }

  void _requireSuccess(String path, http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainingApiException(
        path,
        response.statusCode,
        message: _errorMessage(response.body),
      );
    }
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
