import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/client/api_client.dart';
import '../../../core/client/api_error_message.dart';
import '../models/app_user.dart';

class UserApiException implements Exception {
  const UserApiException(this.path, this.statusCode, {this.message});

  final String path;
  final int statusCode;
  final String? message;

  @override
  String toString() => 'Request to $path failed with status $statusCode';
}

class UserRemoteDataSource {
  const UserRemoteDataSource(this.apiClient);

  final ApiClient apiClient;

  Future<AppUser> getMe() async {
    const path = '/users/me';
    final response = await apiClient.get(path);
    _requireSuccess(path, response);
    return AppUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<AppUser>> getUsers() async {
    const path = '/users';
    final response = await apiClient.get(path);
    _requireSuccess(path, response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => AppUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AppUser> updateRole(String userId, UserRole role) async {
    final path = '/users/$userId/role';
    final response = await apiClient.patch(path, {'role': role.toApiValue()});
    _requireSuccess(path, response);
    return AppUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _requireSuccess(String path, http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UserApiException(
        path,
        response.statusCode,
        message: apiErrorMessage(response.body),
      );
    }
  }
}
