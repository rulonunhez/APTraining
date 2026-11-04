import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../logging/app_error_reporter.dart';

class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;
  final storage = const FlutterSecureStorage();
  Future<bool>? _refreshInFlight;

  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 15),
    this.uploadTimeout = const Duration(minutes: 5),
  }) : _httpClient = client ?? http.Client();

  // Las subidas multipart incluyen el envío del archivo por red móvil.
  final Duration uploadTimeout;

  // ── Tokens ────────────────────────────────────────────────────

  Future<void> saveAccessToken(String token) async =>
      storage.write(key: 'access_token', value: token);

  Future<void> saveRefreshToken(String token) async =>
      storage.write(key: 'refresh_token', value: token);

  Future<String?> getAccessToken() => storage.read(key: 'access_token');
  Future<String?> getRefreshToken() => storage.read(key: 'refresh_token');

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await saveAccessToken(accessToken);
      await saveRefreshToken(refreshToken);
    } catch (_) {
      await clearTokens();
      rethrow;
    }
  }

  Future<void> clearTokens() async {
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
  }

  Future<bool> restoreSession() async {
    final refresh = await getRefreshToken();
    if (refresh == null) {
      await clearTokens();
      return false;
    }

    final access = await getAccessToken();
    if (access != null && !_isAccessTokenExpired(access)) return true;

    final refreshed = await refreshToken();
    if (!refreshed) await clearTokens();
    return refreshed;
  }

  bool _isAccessTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic> || payload['exp'] is! num) {
        return true;
      }
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        (payload['exp'] as num).toInt() * 1000,
      );
      return !expiry.isAfter(DateTime.now().add(const Duration(seconds: 30)));
    } catch (_) {
      return true;
    }
  }

  // ── Headers ───────────────────────────────────────────────────

  Map<String, String> _jsonHeaders(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Map<String, String> _multipartHeaders(String? token) => {
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ── Interceptor central ───────────────────────────────────────
  //
  // Recibe una función que construye y lanza la petición HTTP dado
  // un token. Si recibe 401, refresca el token y reintenta una vez.
  // Si el refresco falla, limpia los tokens y lanza una excepción
  // para que la capa de UI pueda redirigir al login si lo necesita.

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function(String? token) buildRequest, {
    bool retryOnUnauthorized = true,
    Duration? timeout,
  }) async {
    final token = await getAccessToken();
    final response = await _sendRequest(buildRequest, token, timeout);

    if (response.statusCode != 401 || !retryOnUnauthorized) {
      _logHttpFailure(response);
      return response;
    }

    // Another request may already have refreshed the shared session.
    var retryToken = await getAccessToken();
    if (retryToken == null || retryToken == token) {
      final refreshed = await refreshToken();
      if (!refreshed) {
        await clearTokens();
        throw UnauthorizedException(
            'Sesión caducada. Vuelve a iniciar sesión.');
      }
      retryToken = await getAccessToken();
    }

    final retriedResponse =
        await _sendRequest(buildRequest, retryToken, timeout);
    if (retriedResponse.statusCode == 401) {
      _logHttpFailure(retriedResponse);
      await clearTokens();
      throw UnauthorizedException('Sesión caducada. Vuelve a iniciar sesión.');
    }
    _logHttpFailure(retriedResponse);
    return retriedResponse;
  }

  Future<http.Response> _sendRequest(
    Future<http.Response> Function(String? token) buildRequest,
    String? token,
    Duration? timeout,
  ) async {
    try {
      return await buildRequest(token).timeout(timeout ?? requestTimeout);
    } catch (error, stackTrace) {
      AppErrorReporter.recordHandled(
        error,
        stackTrace,
        context: 'HTTP transport request failed',
      );
      rethrow;
    }
  }

  void _logHttpFailure(http.Response response) {
    if (response.statusCode < 400) return;
    final request = response.request;
    AppErrorReporter.recordHttpFailure(
      method: request?.method ?? 'UNKNOWN',
      path: request?.url.path ?? 'unknown',
      statusCode: response.statusCode,
      requestId: response.headers['x-request-id'],
    );
  }

  // ── Métodos públicos ──────────────────────────────────────────

  Future<http.Response> get(String path) {
    final url = Uri.parse('$baseUrl$path');
    return _sendWithRetry(
      (token) => _httpClient.get(url, headers: _jsonHeaders(token)),
    );
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) {
    final url = Uri.parse('$baseUrl$path');
    return _sendWithRetry(
      (token) => _httpClient.post(
        url,
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
      retryOnUnauthorized: !path.startsWith('/auth/'),
    );
  }

  Future<http.Response> put(String path, Map<String, dynamic> body) {
    final url = Uri.parse('$baseUrl$path');
    return _sendWithRetry(
      (token) => _httpClient.put(
        url,
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    );
  }

  Future<http.Response> patch(String path, Map<String, dynamic> body) {
    final url = Uri.parse('$baseUrl$path');
    return _sendWithRetry(
      (token) => _httpClient.patch(
        url,
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    );
  }

  Future<http.Response> delete(String path) {
    final url = Uri.parse('$baseUrl$path');
    return _sendWithRetry(
      (token) => _httpClient.delete(url, headers: _jsonHeaders(token)),
    );
  }

  Future<http.Response> postMultipart(
    String path, {
    required Map<String, String> fields,
    required Future<List<http.MultipartFile>> Function() filesBuilder,
  }) {
    return _sendWithRetry(
      (token) async => _sendMultipart(
        'POST',
        path,
        token,
        fields,
        await filesBuilder(),
      ),
      timeout: uploadTimeout,
    );
  }

  // Subida directa a una URL prefirmada (S3): sin cabecera Authorization,
  // enviando el archivo en streaming para no cargarlo en memoria.
  Future<http.Response> putFileToUrl(
    String url,
    File file, {
    required String contentType,
  }) async {
    try {
      final length = await file.length();
      final request = http.StreamedRequest('PUT', Uri.parse(url))
        ..headers['Content-Type'] = contentType
        ..contentLength = length;
      file.openRead().listen(
            request.sink.add,
            onError: request.sink.addError,
            onDone: request.sink.close,
            cancelOnError: true,
          );
      final streamed = await _httpClient.send(request).timeout(uploadTimeout);
      final response =
          await http.Response.fromStream(streamed).timeout(requestTimeout);
      if (response.statusCode >= 400) {
        AppErrorReporter.recordHttpFailure(
          method: 'PUT',
          path: 'direct-video-upload',
          statusCode: response.statusCode,
          requestId: response.headers['x-amz-request-id'],
        );
      }
      return response;
    } catch (error, stackTrace) {
      AppErrorReporter.recordHandled(
        error,
        stackTrace,
        context: 'Direct video upload failed',
      );
      rethrow;
    }
  }

  Future<http.Response> putMultipart(
    String path, {
    required Map<String, String> fields,
    required Future<List<http.MultipartFile>> Function() filesBuilder,
  }) {
    return _sendWithRetry(
      (token) async => _sendMultipart(
        'PUT',
        path,
        token,
        fields,
        await filesBuilder(),
      ),
      timeout: uploadTimeout,
    );
  }

  // ── Helpers privados ──────────────────────────────────────────

  Future<http.Response> _sendMultipart(
    String method,
    String path,
    String? token,
    Map<String, String> fields,
    List<http.MultipartFile> files,
  ) async {
    final url = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest(method, url)
      ..headers.addAll(_multipartHeaders(token))
      ..fields.addAll(fields)
      ..files.addAll(files);

    final streamed = await _httpClient.send(request).timeout(uploadTimeout);
    return http.Response.fromStream(streamed);
  }

  // ── Refresco de token ─────────────────────────────────────────

  Future<bool> refreshToken() {
    final existingRefresh = _refreshInFlight;
    if (existingRefresh != null) return existingRefresh;

    final refreshFuture = _requestTokenRefresh();
    _refreshInFlight = refreshFuture;
    return refreshFuture.whenComplete(() {
      if (identical(_refreshInFlight, refreshFuture)) _refreshInFlight = null;
    });
  }

  Future<bool> _requestTokenRefresh() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return false;

    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refresh}),
        )
        .timeout(requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> ||
          data['accessToken'] is! String ||
          data['refreshToken'] is! String) {
        throw const FormatException('Invalid token refresh response');
      }
      await saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    }
    if (response.statusCode == 400 ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      return false;
    }
    throw ApiClientException(
      'Token refresh failed with status ${response.statusCode}',
    );
  }
}

// ── Excepción personalizada ───────────────────────────────────────

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException(this.message);

  @override
  String toString() => 'UnauthorizedException: $message';
}

class ApiClientException implements Exception {
  final String message;
  const ApiClientException(this.message);

  @override
  String toString() => 'ApiClientException: $message';
}
