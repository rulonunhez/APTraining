import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ap_training/core/client/api_client.dart';
import 'package:ap_training/features/auth/models/auth_result.dart';
import 'package:ap_training/features/auth/services/auth_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  const configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  final baseUrl = validateApiBaseUrl(
    configuredBaseUrl,
    requireHttps: kReleaseMode,
  );
  return ApiClient(baseUrl: baseUrl);
});

String validateApiBaseUrl(String baseUrl, {required bool requireHttps}) {
  final uri = Uri.tryParse(baseUrl);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw const FormatException('API_BASE_URL must be an absolute HTTP URL');
  }
  if (requireHttps && uri.scheme != 'https') {
    throw StateError('API_BASE_URL must use HTTPS in release builds');
  }
  return baseUrl;
}

enum AuthStatus {
  restoring,
  signedOut,
  authenticating,
  registering,
  authenticated,
  loggingOut,
}

class AuthState {
  const AuthState({this.status = AuthStatus.restoring});

  final AuthStatus status;

  bool get isLoading => status == AuthStatus.restoring;
  bool get isLoggedIn => status == AuthStatus.authenticated;
  bool get isBusy =>
      isLoading ||
      status == AuthStatus.authenticating ||
      status == AuthStatus.registering ||
      status == AuthStatus.loggingOut;
}

final authProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final authService = ref.read(authServiceProvider);
  return AuthStateNotifier(authService);
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiClientProvider));
});

final currentUsernameProvider = FutureProvider.autoDispose<String>((ref) {
  return ref.read(authServiceProvider).getCurrentUsername();
});

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this.authService) : super(const AuthState()) {
    _restoreSession();
  }

  final AuthService authService;

  Future<void> _restoreSession() async {
    var restored = false;
    try {
      restored = await authService.restoreSession();
    } catch (_) {
      restored = false;
    }
    state = AuthState(
      status: restored ? AuthStatus.authenticated : AuthStatus.signedOut,
    );
  }

  Future<AuthResult> login(String email, String password) async {
    state = const AuthState(status: AuthStatus.authenticating);
    final result = await _runAuthOperation(
      () => authService.login(email, password),
    );
    state = AuthState(
      status:
          result.isSuccess ? AuthStatus.authenticated : AuthStatus.signedOut,
    );
    return result;
  }

  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    state = const AuthState(status: AuthStatus.registering);
    final result = await _runAuthOperation(
      () => authService.register(
        username: username,
        email: email,
        password: password,
      ),
    );
    state = const AuthState(status: AuthStatus.signedOut);
    return result;
  }

  Future<AuthResult> logout() async {
    state = const AuthState(status: AuthStatus.loggingOut);
    final result = await _runAuthOperation(
      authService.logout,
      fallback: AuthFailure.remoteLogoutFailed,
    );
    state = const AuthState(status: AuthStatus.signedOut);
    return result;
  }

  Future<AuthResult> _runAuthOperation(
    Future<AuthResult> Function() operation, {
    AuthFailure fallback = AuthFailure.serviceUnavailable,
  }) async {
    try {
      return await operation();
    } catch (_) {
      return AuthResult.failure(fallback);
    }
  }
}
