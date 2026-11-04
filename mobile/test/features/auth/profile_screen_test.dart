import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/core/client/api_client.dart';
import 'package:ap_training/features/auth/providers/auth_provider.dart';
import 'package:ap_training/features/auth/screens/profile_screen.dart';
import 'package:ap_training/features/auth/services/auth_service.dart';
import 'package:ap_training/features/users/models/app_user.dart';
import 'package:ap_training/features/users/providers/users_providers.dart';

void main() {
  testWidgets('shows the username, options, and logout controls',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_ProfileAuthService()),
          currentUserProvider.overrideWith(
            () => _FakeCurrentUserNotifier(
              const AppUser(
                id: 'user-1',
                username: 'ana-gym',
                email: 'ana@example.com',
                role: UserRole.user,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ana-gym'), findsOneWidget);
    expect(find.text('Opciones'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });
}

class _FakeCurrentUserNotifier extends CurrentUserNotifier {
  _FakeCurrentUserNotifier(this.user);

  final AppUser user;

  @override
  Future<AppUser?> build() async => user;
}

class _ProfileAuthService extends AuthService {
  _ProfileAuthService() : super(ApiClient(baseUrl: 'http://localhost'));

  @override
  Future<bool> restoreSession() async => true;
}
