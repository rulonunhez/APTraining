import '../data/group_remote_data_source.dart';
import '../models/user_group.dart';

abstract interface class GroupRepository {
  Future<List<UserGroup>> getGroups();
  Future<UserGroup> getGroup(String id);
  Future<UserGroup> createGroup(UserGroup group);
  Future<UserGroup> updateGroup(String id, UserGroup group);
  Future<void> deleteGroup(String id);
  Future<int> syncAssignments(String id);
}

class RemoteGroupRepository implements GroupRepository {
  const RemoteGroupRepository(this.dataSource);

  final GroupRemoteDataSource dataSource;

  @override
  Future<List<UserGroup>> getGroups() => dataSource.getGroups();

  @override
  Future<UserGroup> getGroup(String id) => dataSource.getGroup(id);

  @override
  Future<UserGroup> createGroup(UserGroup group) =>
      dataSource.createGroup(group);

  @override
  Future<UserGroup> updateGroup(String id, UserGroup group) =>
      dataSource.updateGroup(id, group);

  @override
  Future<void> deleteGroup(String id) => dataSource.deleteGroup(id);

  @override
  Future<int> syncAssignments(String id) => dataSource.syncAssignments(id);
}
