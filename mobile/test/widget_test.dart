// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/core/client/api_client.dart';
import 'package:ap_training/features/auth/providers/auth_provider.dart';
import 'package:ap_training/main.dart';

void main() {
  testWidgets('APTraining opens the login screen without a saved session',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_NoSessionApiClient()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}

class _NoSessionApiClient extends ApiClient {
  _NoSessionApiClient() : super(baseUrl: 'https://gym.test');

  @override
  Future<bool> restoreSession() async => false;
}
