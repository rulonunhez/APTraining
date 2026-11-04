import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/client/api_client.dart';
import '../../../core/client/api_error_message.dart';
import '../models/training_plan.dart';

class TrainingPlanApiException implements Exception {
  const TrainingPlanApiException(this.path, this.statusCode, {this.message});

  final String path;
  final int statusCode;
  final String? message;

  @override
  String toString() => 'Request to $path failed with status $statusCode';
}

class TrainingPlanRemoteDataSource {
  const TrainingPlanRemoteDataSource(this.apiClient);

  final ApiClient apiClient;

  Future<List<TrainingPlan>> getTrainingPlans() async {
    const path = '/training-plans';
    final response = await apiClient.get(path);
    _requireSuccess(path, response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => TrainingPlan.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TrainingPlan> getTrainingPlan(String id) async {
    final path = '/training-plans/$id';
    final response = await apiClient.get(path);
    _requireSuccess(path, response);
    return TrainingPlan.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TrainingPlan> createTrainingPlan(TrainingPlan plan) async {
    const path = '/training-plans';
    final response = await apiClient.post(path, plan.toJson());
    _requireSuccess(path, response);
    return TrainingPlan.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TrainingPlan> updateTrainingPlan(String id, TrainingPlan plan) async {
    final path = '/training-plans/$id';
    final response = await apiClient.put(path, plan.toJson());
    _requireSuccess(path, response);
    return TrainingPlan.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteTrainingPlan(String id) async {
    final path = '/training-plans/$id';
    final response = await apiClient.delete(path);
    _requireSuccess(path, response);
  }

  void _requireSuccess(String path, http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainingPlanApiException(
        path,
        response.statusCode,
        message: apiErrorMessage(response.body),
      );
    }
  }
}
