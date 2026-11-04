import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ap_training/features/auth/providers/auth_provider.dart';

import '../data/group_remote_data_source.dart';
import '../models/user_group.dart';
import '../repositories/group_repository.dart';
import 'users_providers.dart';

final groupRemoteDataSourceProvider = Provider<GroupRemoteDataSource>(
  (ref) => GroupRemoteDataSource(ref.watch(apiClientProvider)),
);

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => RemoteGroupRepository(ref.watch(groupRemoteDataSourceProvider)),
);

final groupsProvider = AsyncNotifierProvider<GroupsNotifier, List<UserGroup>>(
  GroupsNotifier.new,
);

class GroupsNotifier extends AsyncNotifier<List<UserGroup>> {
  @override
  Future<List<UserGroup>> build() {
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
    return ref.watch(groupRepositoryProvider).getGroups();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(groupRepositoryProvider).getGroups(),
    );
  }

  Future<UserGroup> createGroup(UserGroup group) async {
    final created = await ref.read(groupRepositoryProvider).createGroup(group);
    await refresh();
    return created;
  }

  Future<UserGroup> updateGroup(String id, UserGroup group) async {
    final updated =
        await ref.read(groupRepositoryProvider).updateGroup(id, group);
    await refresh();
    return updated;
  }

  Future<void> deleteGroup(String id) async {
    await ref.read(groupRepositoryProvider).deleteGroup(id);
    state = state.whenData(
      (groups) => groups.where((group) => group.id != id).toList(),
    );
  }

  Future<int> syncAssignments(String id) =>
      ref.read(groupRepositoryProvider).syncAssignments(id);
}
