import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ap_training/core/client/api_client.dart';
import 'package:ap_training/core/logging/app_error_reporter.dart';
import 'package:ap_training/features/auth/models/auth_result.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final ApiClient apiClient;

  AuthService(this.apiClient);

  Future<bool> restoreSession() => apiClient.restoreSession();

  Future<String> getCurrentUsername() async {
    final response = await apiClient.get('/users/me');
    if (response.statusCode != 200) {
      throw StateError('No se pudo cargar el perfil (${response.statusCode}).');
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> ||
        data['username'] is! String ||
        (data['username'] as String).trim().isEmpty) {
      throw const FormatException('El perfil no contiene un nombre válido.');
    }
    return (data['username'] as String).trim();
  }

  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await apiClient.post('/auth/login', {
        'email': email,
        'password': password,
      });
      debugPrint('[APTraining][Login] HTTP status=${response.statusCode}');

      if (response.statusCode != 200) {
        return AuthResult.failure(
          response.statusCode == 401
              ? AuthFailure.invalidCredentials
              : _failureForStatus(response.statusCode),
        );
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> ||
          data['accessToken'] is! String ||
          data['refreshToken'] is! String) {
        return const AuthResult.failure(AuthFailure.invalidResponse);
      }

      await apiClient.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return const AuthResult.success();
    } on TimeoutException catch (error) {
      debugPrint('[APTraining][Login] timeout: $error');
      return const AuthResult.failure(AuthFailure.networkUnavailable);
    } on http.ClientException catch (error) {
      debugPrint('[APTraining][Login] HTTP client error: $error');
      return const AuthResult.failure(AuthFailure.networkUnavailable);
    } on FormatException catch (error) {
      debugPrint('[APTraining][Login] invalid response: $error');
      return const AuthResult.failure(AuthFailure.invalidResponse);
    } catch (error, stackTrace) {
      debugPrint('[APTraining][Login] unexpected ${error.runtimeType}: $error');
      AppErrorReporter.recordHandled(
        error,
        stackTrace,
        context: 'Unexpected login failure',
      );
      return const AuthResult.failure(AuthFailure.serviceUnavailable);
    }
  }

  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await apiClient.post('/auth/register', {
        'username': username,
        'email': email,
        'password': password,
      });
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const AuthResult.success();
      }
      return AuthResult.failure(
        response.statusCode == 409
            ? AuthFailure.accountAlreadyExists
            : _failureForStatus(response.statusCode),
      );
    } on TimeoutException {
      return const AuthResult.failure(AuthFailure.networkUnavailable);
    } on http.ClientException {
      return const AuthResult.failure(AuthFailure.networkUnavailable);
    } catch (_) {
      return const AuthResult.failure(AuthFailure.serviceUnavailable);
    }
  }

  Future<AuthResult> logout() async {
    var result = const AuthResult.success();
    try {
      final refreshToken = await apiClient.getRefreshToken();
      if (refreshToken != null) {
        final response = await apiClient.post('/auth/logout', {
          'refreshToken': refreshToken,
        });
        if (response.statusCode < 200 || response.statusCode >= 300) {
          result = const AuthResult.failure(AuthFailure.remoteLogoutFailed);
        }
      }
    } on TimeoutException {
      result = const AuthResult.failure(AuthFailure.remoteLogoutFailed);
    } on http.ClientException {
      result = const AuthResult.failure(AuthFailure.remoteLogoutFailed);
    } catch (_) {
      result = const AuthResult.failure(AuthFailure.remoteLogoutFailed);
    }

    try {
      await apiClient.clearTokens();
    } catch (_) {
      return const AuthResult.failure(AuthFailure.localSessionCleanupFailed);
    }
    return result;
  }

  AuthFailure _failureForStatus(int statusCode) {
    if (statusCode == 400 || statusCode == 422) return AuthFailure.invalidInput;
    if (statusCode >= 500) return AuthFailure.serviceUnavailable;
    return AuthFailure.serviceUnavailable;
  }
}
