import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/client/api_client.dart';
import '../../../core/client/api_error_message.dart';
import '../models/workout_history_entry.dart';
import '../models/workout_history_filter.dart';

class WorkoutHistoryApiException implements Exception {
  const WorkoutHistoryApiException(this.path, this.statusCode, {this.message});

  final String path;
  final int statusCode;
  final String? message;

  @override
  String toString() => 'Request to $path failed with status $statusCode';
}

class WorkoutHistoryRemoteDataSource {
  const WorkoutHistoryRemoteDataSource(this.apiClient);

  final ApiClient apiClient;

  Future<List<WorkoutHistoryEntry>> getWorkoutHistory() async {
    const path = '/workout-history';
    final response = await apiClient.get(path);
    _requireSuccess(path, response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => WorkoutHistoryEntry.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<WorkoutHistoryEntry> recordActivity(
    WorkoutHistoryEntry entry,
  ) async {
    const path = '/workout-history';
    final response = await apiClient.post(path, entry.toJson());
    _requireSuccess(path, response);
    return WorkoutHistoryEntry.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Búsqueda con filtros. Entrenos y ejercicios conviven con lógica OR:
  /// el backend devuelve registros que contengan al menos uno de ellos.
  /// [userId] solo lo pueden usar entrenadores y admin.
  Future<List<WorkoutHistoryEntry>> searchWorkoutHistory({
    DateTime? from,
    DateTime? to,
    List<String> trainingIds = const [],
    List<String> exerciseIds = const [],
    String? userId,
  }) async {
    final path = Uri(
      path: '/workout-history/search',
      queryParameters: <String, dynamic>{
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
        if (trainingIds.isNotEmpty) 'trainingIds': trainingIds,
        if (exerciseIds.isNotEmpty) 'exerciseIds': exerciseIds,
        if (userId != null) 'userId': userId,
      },
    ).toString();
    final response = await apiClient.get(path);
    _requireSuccess(path, response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => WorkoutHistoryEntry.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();
  }

  /// Entrenos y ejercicios presentes en el historial del usuario consultado,
  /// para alimentar los selectores de filtro.
  Future<WorkoutHistoryFilterOptions> getFilterOptions({String? userId}) async {
    final path = userId == null
        ? '/workout-history/filter-options'
        : Uri(
            path: '/workout-history/filter-options',
            queryParameters: {'userId': userId},
          ).toString();
    final response = await apiClient.get(path);
    _requireSuccess(path, response);
    return WorkoutHistoryFilterOptions.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  void _requireSuccess(String path, http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WorkoutHistoryApiException(
        path,
        response.statusCode,
        message: apiErrorMessage(response.body),
      );
    }
  }
}
