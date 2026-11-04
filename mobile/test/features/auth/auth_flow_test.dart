import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ap_training/core/client/api_client.dart';
import 'package:ap_training/core/navigation/app_router.dart';
import 'package:ap_training/features/auth/providers/auth_provider.dart';
import 'package:ap_training/features/auth/models/auth_result.dart';
import 'package:ap_training/features/auth/screens/login_screen.dart';
import 'package:ap_training/features/auth/screens/register_screen.dart';
import 'package:ap_training/features/auth/services/auth_service.dart';
import 'package:ap_training/features/auth/widgets/auth_logout_button.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('release API URL must use HTTPS', () {
    expect(
      () => validateApiBaseUrl('http://api.example.com', requireHttps: true),
      throwsStateError,
    );
    expect(
      validateApiBaseUrl('https://api.example.com', requireHttps: true),
      'https://api.example.com',
    );
  });

  test('registration stays public while other routes remain protected', () {
    expect(
      authRedirect(isLoading: false, isLoggedIn: false, path: '/register'),
      isNull,
    );
    expect(
      authRedirect(isLoading: false, isLoggedIn: false, path: '/planning'),
      '/login',
    );
    expect(
      authRedirect(isLoading: false, isLoggedIn: true, path: '/register'),
      '/planning',
    );
  });

  test('login does not try to refresh after invalid credentials', () async {
    final paths = <String>[];
    final client = _MemoryApiClient(
      MockClient((request) async {
        paths.add(request.url.path);
        return http.Response('', 401);
      }),
    )..storedRefreshToken = 'existing-refresh-token';

    final response = await client.post('/auth/login', {
      'email': 'user@example.com',
      'password': 'incorrect',
    });

    expect(response.statusCode, 401);
    expect(paths, ['/auth/login']);
  });

  test('protected request refreshes once and retries with the new access token',
      () async {
    final paths = <String>[];
    final authorizationHeaders = <String?>[];
    final client = _MemoryApiClient(
      MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/auth/refresh') {
          return http.Response(
            jsonEncode({
              'accessToken': 'new-access-token',
              'refreshToken': 'new-refresh-token',
            }),
            200,
          );
        }

        authorizationHeaders.add(request.headers['Authorization']);
        if (authorizationHeaders.length == 1) return http.Response('', 401);
        return http.Response('{}', 200);
      }),
    )
      ..accessToken = 'expired-access-token'
      ..storedRefreshToken = 'old-refresh-token';

    final response = await client.get('/protected');

    expect(response.statusCode, 200);
    expect(paths, ['/protected', '/auth/refresh', '/protected']);
    expect(authorizationHeaders, [
      'Bearer expired-access-token',
      'Bearer new-access-token',
    ]);
    expect(client.storedRefreshToken, 'new-refresh-token');
  });

  test('concurrent unauthorized requests share one refresh operation',
      () async {
    var refreshCalls = 0;
    final client = _MemoryApiClient(
      MockClient((request) async {
        if (request.url.path == '/auth/refresh') {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response(
            jsonEncode({
              'accessToken': 'new-access-token',
              'refreshToken': 'new-refresh-token',
            }),
            200,
          );
        }
        if (request.headers['Authorization'] == 'Bearer expired-access-token') {
          return http.Response('', 401);
        }
        return http.Response('{}', 200);
      }),
    )
      ..accessToken = 'expired-access-token'
      ..storedRefreshToken = 'old-refresh-token';

    final responses = await Future.wait([
      client.get('/protected/first'),
      client.get('/protected/second'),
    ]);

    expect(responses.map((response) => response.statusCode), [200, 200]);
    expect(refreshCalls, 1);
    expect(client.storedRefreshToken, 'new-refresh-token');
  });

  test('session restoration refreshes an expired access token at startup',
      () async {
    final paths = <String>[];
    final client = _MemoryApiClient(
      MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          jsonEncode({
            'accessToken': 'replacement-access-token',
            'refreshToken': 'replacement-refresh-token',
          }),
          200,
        );
      }),
    )
      ..accessToken = _jwtWithExpiry(const Duration(seconds: -60))
      ..storedRefreshToken = 'saved-refresh-token';

    final restored = await client.restoreSession();

    expect(restored, isTrue);
    expect(paths, ['/auth/refresh']);
    expect(client.accessToken, 'replacement-access-token');
    expect(client.storedRefreshToken, 'replacement-refresh-token');
  });

  test('auth notifier restores logged-in state after refreshing on startup',
      () async {
    final client = _MemoryApiClient(
      MockClient((request) async {
        return http.Response(
          jsonEncode({
            'accessToken': 'restored-access-token',
            'refreshToken': 'rotated-refresh-token',
          }),
          200,
        );
      }),
    )..storedRefreshToken = 'saved-refresh-token';
    final notifier = AuthStateNotifier(AuthService(client));

    final state = await notifier.stream.firstWhere((state) => !state.isLoading);

    expect(state.isLoggedIn, isTrue);
    expect(client.accessToken, 'restored-access-token');
    expect(client.storedRefreshToken, 'rotated-refresh-token');
    notifier.dispose();
  });

  test('session restoration keeps an unexpired access token without network',
      () async {
    final paths = <String>[];
    final client = _MemoryApiClient(
      MockClient((request) async {
        paths.add(request.url.path);
        return http.Response('', 500);
      }),
    )
      ..accessToken = _jwtWithExpiry(const Duration(minutes: 5))
      ..storedRefreshToken = 'saved-refresh-token';

    expect(await client.restoreSession(), isTrue);
    expect(paths, isEmpty);
  });

  test('rejected refresh clears the local session', () async {
    final client = _MemoryApiClient(
      MockClient((request) async {
        if (request.url.path == '/auth/refresh') return http.Response('', 401);
        return http.Response('', 401);
      }),
    )
      ..accessToken = 'expired-access-token'
      ..storedRefreshToken = 'revoked-refresh-token';

    await expectLater(
      client.get('/protected'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(client.accessToken, isNull);
    expect(client.storedRefreshToken, isNull);
  });

  test('transient refresh failure preserves stored credentials', () async {
    final client = _MemoryApiClient(
      MockClient((request) async {
        if (request.url.path == '/auth/refresh') return http.Response('', 503);
        return http.Response('', 401);
      }),
    )
      ..accessToken = 'expired-access-token'
      ..storedRefreshToken = 'still-valid-refresh-token';

    await expectLater(
      client.get('/protected'),
      throwsA(isA<ApiClientException>()),
    );
    expect(client.accessToken, 'expired-access-token');
    expect(client.storedRefreshToken, 'still-valid-refresh-token');
  });

  test('multipart retry builds fresh file streams after token refresh',
      () async {
    var fileBuilds = 0;
    final client = _MemoryApiClient(
      MockClient((request) async {
        if (request.url.path == '/auth/refresh') {
          return http.Response(
            jsonEncode({
              'accessToken': 'new-access-token',
              'refreshToken': 'new-refresh-token',
            }),
            200,
          );
        }
        if (request.headers['Authorization'] == 'Bearer expired-access-token') {
          return http.Response('', 401);
        }
        return http.Response('', 200);
      }),
    )
      ..accessToken = 'expired-access-token'
      ..storedRefreshToken = 'old-refresh-token';

    final response = await client.postMultipart(
      '/upload',
      fields: const {},
      filesBuilder: () async {
        fileBuilds++;
        return [http.MultipartFile.fromString('file', 'payload')];
      },
    );

    expect(response.statusCode, 200);
    expect(fileBuilds, 2);
  });

  test('request timeout is surfaced to the caller', () async {
    final client = _MemoryApiClient(
      MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200);
      }),
      requestTimeout: const Duration(milliseconds: 5),
    );

    await expectLater(
      client.post('/auth/login', {'email': 'user@example.com'}),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('auth service saves tokens only after a successful login', () async {
    final client = _StubApiClient();
    final service = AuthService(client);

    client.response = http.Response(
      jsonEncode({'accessToken': 'access', 'refreshToken': 'refresh'}),
      200,
    );
    expect((await service.login('user@example.com', 'password')).isSuccess,
        isTrue);
    expect(client.accessToken, 'access');
    expect(client.storedRefreshToken, 'refresh');

    client.response = http.Response('', 401);
    expect(
      (await service.login('user@example.com', 'wrong-password')).failure,
      AuthFailure.invalidCredentials,
    );
  });

  test('auth service distinguishes server and malformed login responses',
      () async {
    final client = _StubApiClient();
    final service = AuthService(client);

    client.response = http.Response('', 503);
    expect(
      (await service.login('user@example.com', 'password')).failure,
      AuthFailure.serviceUnavailable,
    );

    client.response = http.Response('{"accessToken":42}', 200);
    expect(
      (await service.login('user@example.com', 'password')).failure,
      AuthFailure.invalidResponse,
    );

    client.postError = http.ClientException('Network unavailable');
    expect(
      (await service.login('user@example.com', 'password')).failure,
      AuthFailure.networkUnavailable,
    );
  });

  test('registration sends only the backend user fields', () async {
    final client = _StubApiClient();
    final service = AuthService(client);

    expect(
      (await service.register(
        username: 'ana-gym',
        email: 'ana@example.com',
        password: 'secure-password',
      ))
          .isSuccess,
      isTrue,
    );
    expect(client.lastPostPath, '/auth/register');
    expect(client.lastPostBody, {
      'username': 'ana-gym',
      'email': 'ana@example.com',
      'password': 'secure-password',
    });

    client.response = http.Response('Conflict', 409);
    expect(
      (await service.register(
        username: 'ana-gym',
        email: 'ana@example.com',
        password: 'secure-password',
      ))
          .failure,
      AuthFailure.accountAlreadyExists,
    );
  });

  test('logout revokes the refresh token and clears local credentials',
      () async {
    final client = _StubApiClient()
      ..accessToken = 'access'
      ..storedRefreshToken = 'refresh';

    await AuthService(client).logout();

    expect(client.lastPostPath, '/auth/logout');
    expect(client.lastPostBody, {'refreshToken': 'refresh'});
    expect(client.accessToken, isNull);
    expect(client.storedRefreshToken, isNull);
  });

  test('logout clears local credentials even if remote revocation fails',
      () async {
    final client = _StubApiClient()
      ..accessToken = 'access'
      ..storedRefreshToken = 'refresh'
      ..postError = StateError('API unavailable');

    final result = await AuthService(client).logout();
    expect(result.failure, AuthFailure.remoteLogoutFailed);
    expect(client.accessToken, isNull);
    expect(client.storedRefreshToken, isNull);
  });

  testWidgets('login shows a connection error and stops loading on exception',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _ThrowingAuthNotifier()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('login-email')), 'user@example.com');
    await tester.enterText(find.byKey(const Key('login-password')), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'No se pudo iniciar sesión. Comprueba tu conexión e inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  test('notifier owns login, registration, and logout state transitions',
      () async {
    final service = _DeferredAuthService();
    final notifier = AuthStateNotifier(service);
    await notifier.stream.firstWhere((state) => !state.isLoading);

    final login = notifier.login('user@example.com', 'password');
    expect(notifier.state.status, AuthStatus.authenticating);
    service.loginResult.complete(
      const AuthResult.failure(AuthFailure.invalidCredentials),
    );
    expect((await login).failure, AuthFailure.invalidCredentials);
    expect(notifier.state.status, AuthStatus.signedOut);

    final registration = notifier.register(
      username: 'ana',
      email: 'ana@example.com',
      password: 'password',
    );
    expect(notifier.state.status, AuthStatus.registering);
    service.registerResult.complete(const AuthResult.success());
    expect((await registration).isSuccess, isTrue);
    expect(notifier.state.status, AuthStatus.signedOut);

    final logout = notifier.logout();
    expect(notifier.state.status, AuthStatus.loggingOut);
    service.logoutResult.complete(const AuthResult.success());
    expect((await logout).isSuccess, isTrue);
    expect(notifier.state.status, AuthStatus.signedOut);
    notifier.dispose();
  });

  test('notifier leaves busy state after an unexpected service exception',
      () async {
    final service = _DeferredAuthService();
    final notifier = AuthStateNotifier(service);
    await notifier.stream.firstWhere((state) => !state.isLoading);

    final registration = notifier.register(
      username: 'ana',
      email: 'ana@example.com',
      password: 'password',
    );
    expect(notifier.state.status, AuthStatus.registering);
    service.registerResult.completeError(StateError('Unexpected failure'));

    expect((await registration).failure, AuthFailure.serviceUnavailable);
    expect(notifier.state.status, AuthStatus.signedOut);
    notifier.dispose();
  });

  testWidgets('login validates email before calling the auth notifier',
      (tester) async {
    final notifier = _ControlledAuthNotifier();
    await tester.pumpWidget(_loginHarness(notifier));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('login-email')), 'invalid-email');
    await tester.enterText(find.byKey(const Key('login-password')), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump();

    expect(
        find.text('Introduce un correo electrónico válido.'), findsOneWidget);
    expect(notifier.loginCalls, 0);
  });

  testWidgets('login password visibility can be toggled', (tester) async {
    await tester.pumpWidget(_loginHarness(_ControlledAuthNotifier()));
    await tester.pumpAndSettle();

    expect(_passwordIsObscured(tester, const Key('login-password')), isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(_passwordIsObscured(tester, const Key('login-password')), isFalse);
  });

  testWidgets('registration validates matching passwords before submission',
      (tester) async {
    final client = _StubApiClient();
    await tester.pumpWidget(_registerHarness(client));
    await tester.enterText(find.byKey(const Key('register-username')), 'ana');
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'ana@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'password-one',
    );
    await tester.enterText(
      find.byKey(const Key('register-confirm-password')),
      'password-two',
    );
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();

    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(client.lastPostPath, isNull);
  });

  testWidgets('registration shows success only after API accepts the request',
      (tester) async {
    final client = _StubApiClient()
      ..response = http.Response('Usuario registrado', 200);
    await tester.pumpWidget(_registerHarness(client));
    await _fillRegisterForm(tester);
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Cuenta creada'), findsOneWidget);
    expect(find.text('Ya puedes iniciar sesión con tu nueva cuenta.'),
        findsOneWidget);
    expect(client.lastPostBody, {
      'username': 'ana-gym',
      'email': 'ana@example.com',
      'password': 'secure-password',
    });
  });

  testWidgets('registration failure remains on the form with an error',
      (tester) async {
    final client = _StubApiClient()..response = http.Response('Conflict', 409);
    await tester.pumpWidget(_registerHarness(client));
    await _fillRegisterForm(tester);
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(
      find.text('Ya existe una cuenta con esos datos.'),
      findsOneWidget,
    );
  });

  testWidgets('login and registration links navigate between public screens',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _ControlledAuthNotifier()),
          apiClientProvider.overrideWithValue(_StubApiClient()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    await tester.ensureVisible(find.text('Ya tengo una cuenta'));
    await tester.tap(find.text('Ya tengo una cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    router.dispose();
  });

  testWidgets('logout requires confirmation before ending the session',
      (tester) async {
    final notifier = _LogoutAuthNotifier();
    await tester.pumpWidget(_logoutHarness(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    expect(notifier.logoutCalls, 0);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(notifier.logoutCalls, 0);

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(notifier.logoutCalls, 1);
  });

  testWidgets('logout explains when server revocation fails', (tester) async {
    final notifier = _LogoutAuthNotifier(throwsOnLogout: true);
    await tester.pumpWidget(_logoutHarness(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'La sesión se cerró en este dispositivo, pero no se pudo revocar en el servidor.',
      ),
      findsOneWidget,
    );
  });
}

Widget _logoutHarness(_LogoutAuthNotifier notifier) => ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [const AuthLogoutButton()]),
        ),
      ),
    );

Widget _loginHarness(_ControlledAuthNotifier notifier) => ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(home: LoginScreen()),
    );

Widget _registerHarness(_StubApiClient client) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(client)],
      child: const MaterialApp(home: RegisterScreen()),
    );

Future<void> _fillRegisterForm(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('register-username')), 'ana-gym');
  await tester.enterText(
    find.byKey(const Key('register-email')),
    'ana@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('register-password')),
    'secure-password',
  );
  await tester.enterText(
    find.byKey(const Key('register-confirm-password')),
    'secure-password',
  );
}

bool _passwordIsObscured(WidgetTester tester, Key fieldKey) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(fieldKey),
        matching: find.byType(EditableText),
      ),
    )
    .obscureText;

class _MemoryApiClient extends ApiClient {
  _MemoryApiClient(
    http.Client client, {
    super.requestTimeout,
  }) : super(baseUrl: 'https://gym.test', client: client);

  String? accessToken;
  String? storedRefreshToken;

  @override
  Future<void> saveAccessToken(String token) async => accessToken = token;

  @override
  Future<void> saveRefreshToken(String token) async =>
      storedRefreshToken = token;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => storedRefreshToken;

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    storedRefreshToken = null;
  }
}

class _StubApiClient extends _MemoryApiClient {
  _StubApiClient() : super(MockClient((_) async => http.Response('', 200)));

  http.Response response = http.Response('', 200);
  String? lastPostPath;
  Map<String, dynamic>? lastPostBody;
  Object? postError;

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    lastPostPath = path;
    lastPostBody = body;
    if (postError != null) throw postError!;
    return response;
  }
}

class _ThrowingAuthNotifier extends AuthStateNotifier {
  _ThrowingAuthNotifier() : super(AuthService(_NoTokenApiClient()));

  @override
  Future<AuthResult> login(String email, String password) async {
    throw Exception('Network unavailable');
  }
}

class _LogoutAuthNotifier extends AuthStateNotifier {
  _LogoutAuthNotifier({this.throwsOnLogout = false})
      : super(AuthService(_NoTokenApiClient()));

  final bool throwsOnLogout;
  int logoutCalls = 0;

  @override
  Future<AuthResult> logout() async {
    logoutCalls++;
    if (throwsOnLogout) {
      return const AuthResult.failure(AuthFailure.remoteLogoutFailed);
    }
    return const AuthResult.success();
  }
}

class _ControlledAuthNotifier extends AuthStateNotifier {
  _ControlledAuthNotifier() : super(AuthService(_NoTokenApiClient()));

  int loginCalls = 0;

  @override
  Future<AuthResult> login(String email, String password) async {
    loginCalls++;
    return const AuthResult.success();
  }
}

class _DeferredAuthService extends AuthService {
  _DeferredAuthService() : super(_NoTokenApiClient());

  final loginResult = Completer<AuthResult>();
  final registerResult = Completer<AuthResult>();
  final logoutResult = Completer<AuthResult>();

  @override
  Future<AuthResult> login(String email, String password) => loginResult.future;

  @override
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) =>
      registerResult.future;

  @override
  Future<AuthResult> logout() => logoutResult.future;

  @override
  Future<bool> restoreSession() async => false;
}

class _NoTokenApiClient extends ApiClient {
  _NoTokenApiClient() : super(baseUrl: 'https://gym.test');

  @override
  Future<void> clearTokens() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;
}

String _jwtWithExpiry(Duration fromNow) {
  final expiry = DateTime.now().add(fromNow).millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'exp': expiry})))
      .replaceAll('=', '');
  return 'header.$payload.signature';
}
