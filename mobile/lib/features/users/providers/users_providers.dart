import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ap_training/features/auth/providers/auth_provider.dart';

import '../data/user_remote_data_source.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';

final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>(
  (ref) => UserRemoteDataSource(ref.watch(apiClientProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => RemoteUserRepository(ref.watch(userRemoteDataSourceProvider)),
);

/// Usuario autenticado con su rol. Se recarga al iniciar sesión y se
/// vacía al cerrarla.
final currentUserProvider = AsyncNotifierProvider<CurrentUserNotifier, AppUser?>(
  CurrentUserNotifier.new,
);

class CurrentUserNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() {
    ref.listen(
      authProvider.select((authState) => authState.isLoggedIn),
      (wasLoggedIn, isLoggedIn) {
        if (isLoggedIn && wasLoggedIn != true) {
          refresh();
        } else if (!isLoggedIn) {
          state = const AsyncData(null);
        }
      },
    );
    if (!ref.read(authProvider).isLoggedIn) return Future.value(null);
    return ref.watch(userRepositoryProvider).getMe();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(userRepositoryProvider).getMe(),
    );
  }
}

/// Listado completo de usuarios. Solo disponible para entrenadores y admin;
/// el backend responde 403 para el resto.
final usersProvider = AsyncNotifierProvider<UsersNotifier, List<AppUser>>(
  UsersNotifier.new,
);

class UsersNotifier extends AsyncNotifier<List<AppUser>> {
  @override
  Future<List<AppUser>> build() {
    ref.listen(
      authProvider.select((authState) => authState.isLoggedIn),
      (wasLoggedIn, isLoggedIn) {
        if (isLoggedIn && wasLoggedIn != true) {
          refresh();
        } else if (!isLoggedIn) {
          state = const AsyncData([]);
        }
      },
    );
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    if (currentUser == null || !currentUser.canManageGroups) {
      return Future.value(const []);
    }
    return ref.watch(userRepositoryProvider).getUsers();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(userRepositoryProvider).getUsers(),
    );
  }

  Future<AppUser> updateRole(String userId, UserRole role) async {
    final updated =
        await ref.read(userRepositoryProvider).updateRole(userId, role);
    state = state.whenData(
      (users) => [
        for (final user in users) user.id == userId ? updated : user,
      ],
    );
    return updated;
  }
}
