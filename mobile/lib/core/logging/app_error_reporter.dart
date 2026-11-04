import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';
import 'package:ap_training/firebase_options.dart';

class AppErrorReporter {
  AppErrorReporter._();

  static bool _crashlyticsEnabled = false;
  static const bool _sendSmokeTest =
      bool.fromEnvironment('CRASHLYTICS_SMOKE_TEST', defaultValue: false);

  static Future<void> initialize({required VoidCallback appRunner}) async {
    install();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _crashlyticsEnabled = true;
    } catch (error, stackTrace) {
      developer.log(
        'Firebase Crashlytics is unavailable; continuing with local error logging',
        name: 'APTraining',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }

    appRunner();

    if (_crashlyticsEnabled && _sendSmokeTest) {
      await _report(
        'APTraining Crashlytics DEV smoke test',
        StackTrace.current,
        reason: 'Manual Crashlytics integration verification',
        fatal: false,
      );
    }
  }

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      record(
        details.exception,
        details.stack ?? StackTrace.current,
        context: 'Flutter framework error',
        fatal: true,
      );
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      if (_isGoogleFontsDownloadFailure(stackTrace)) {
        recordHandled(
          error,
          stackTrace,
          context: 'Google Fonts download failed; using fallback font',
        );
        return true;
      }
      if (_isHardwareKeyboardAssertion(error, stackTrace)) {
        recordHandled(
          error,
          stackTrace,
          context: 'Known Flutter framework assertion in HardwareKeyboard '
              '(flutter/flutter#157797); only reachable in debug builds',
        );
        return true;
      }
      record(
        error,
        stackTrace,
        context: 'Uncaught platform error',
        fatal: true,
      );
      return true;
    };
  }

  static bool _isGoogleFontsDownloadFailure(StackTrace stackTrace) =>
      stackTrace.toString().contains('google_fonts_base.dart');

  /// Bug conocido del framework: el assert de `HardwareKeyboard` salta cuando
  /// la plataforma envía un evento de tecla que no encaja en su modelo (por
  /// ejemplo, desde un WebView). Los asserts no existen en builds release, así
  /// que no es un fallo fatal real y no debe ensuciar Crashlytics.
  static bool _isHardwareKeyboardAssertion(
    Object error,
    StackTrace stackTrace,
  ) =>
      error is AssertionError &&
      stackTrace.toString().contains('hardware_keyboard.dart');

  static void recordHandled(
    Object error,
    StackTrace stackTrace, {
    required String context,
  }) {
    _write(error, stackTrace, context: context, level: 900);
    unawaited(
      _report(
        error.runtimeType.toString(),
        stackTrace,
        reason: context,
        fatal: false,
      ),
    );
  }

  static void recordHttpFailure({
    required String method,
    required String path,
    required int statusCode,
    String? requestId,
  }) {
    developer.log(
      'HTTP request failed method=$method path=$path '
      'status=$statusCode${requestId == null ? '' : ' requestId=$requestId'}',
      name: 'APTraining.Http',
      level: 900,
    );
    if (!_crashlyticsEnabled) return;

    unawaited(
      _logCrashlytics(
        'HTTP request failed method=$method status=$statusCode'
        '${requestId == null ? '' : ' requestId=$requestId'}',
      ),
    );

    if (statusCode >= 500) {
      unawaited(
        _report(
          'Backend returned HTTP $statusCode',
          StackTrace.current,
          reason: 'HTTP request failed',
          information: [
            'method=$method',
            'status_code=$statusCode',
            if (requestId != null) 'request_id=$requestId',
          ],
          fatal: false,
        ),
      );
    }
  }

  static void record(
    Object error,
    StackTrace stackTrace, {
    required String context,
    bool fatal = false,
  }) {
    _write(error, stackTrace, context: context, level: 1000);
    unawaited(
      _report(
        error.runtimeType.toString(),
        stackTrace,
        reason: context,
        fatal: fatal,
      ),
    );
  }

  static void _write(
    Object error,
    StackTrace stackTrace, {
    required String context,
    int level = 1000,
  }) {
    developer.log(
      context,
      name: 'APTraining',
      error: error,
      stackTrace: stackTrace,
      level: level,
    );
  }

  static Future<void> _report(
    Object error,
    StackTrace stackTrace, {
    required String reason,
    Iterable<Object> information = const [],
    required bool fatal,
  }) async {
    if (!_crashlyticsEnabled) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        information: information,
        fatal: fatal,
      );
    } catch (reportingError, reportingStackTrace) {
      developer.log(
        'Crashlytics failed to record an app error',
        name: 'APTraining',
        error: reportingError,
        stackTrace: reportingStackTrace,
        level: 1000,
      );
    }
  }

  static Future<void> _logCrashlytics(String message) async {
    try {
      await FirebaseCrashlytics.instance.log(message);
    } catch (error, stackTrace) {
      developer.log(
        'Crashlytics failed to write an app log',
        name: 'APTraining',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }
}
