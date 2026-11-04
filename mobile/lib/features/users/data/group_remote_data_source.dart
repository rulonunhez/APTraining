import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/client/api_client.dart';
import '../../../core/client/api_error_message.dart';
import '../models/user_group.dart';

class GroupApiException implements Exception {
  const GroupApiException(this.path, this.statusCode, {this.message});

  final String path;
  final int statusCode;
  final String? message;

  @override
  String toString() => 'Request to $path failed with status $statusCode';
}

class GroupRemoteDataSource {
  const GroupRemoteDataSource(this.apiClient);

  final ApiClient apiClient;

  Future<List<UserGroup>> getGroups() async {
    const path = '/groups';
    final response = await apiClient.get(path);
    _requireSuccess(path, response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => UserGroup.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserGroup> getGroup(String id) async {
    final path = '/groups/$id';
    final response = await apiClient.get(path);
    _requireSuccess(path, response);
    return UserGroup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserGroup> createGroup(UserGroup group) async {
    const path = '/groups';
    final response = await apiClient.post(path, group.toJson());
    _requireSuccess(path, response);
    return UserGroup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserGroup> updateGroup(String id, UserGroup group) async {
    final path = '/groups/$id';
    final response = await apiClient.put(path, group.toJson());
    _requireSuccess(path, response);
    return UserGroup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteGroup(String id) async {
    final path = '/groups/$id';
    final response = await apiClient.delete(path);
    _requireSuccess(path, response);
  }

  /// Sincronización aditiva: asigna a los miembros actuales los planes que
  /// se asignaron originalmente a través de este grupo.
  Future<int> syncAssignments(String id) async {
    final path = '/groups/$id/sync-assignments';
    final response = await apiClient.post(path, const {});
    _requireSuccess(path, response);
    final data = jsonDecode(response.body);
    return data is Map<String, dynamic> && data['created'] is num
        ? (data['created'] as num).toInt()
        : 0;
  }

  void _requireSuccess(String path, http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GroupApiException(
        path,
        response.statusCode,
        message: apiErrorMessage(response.body),
      );
    }
  }
}
