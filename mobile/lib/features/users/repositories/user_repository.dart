import '../data/user_remote_data_source.dart';
import '../models/app_user.dart';

abstract interface class UserRepository {
  Future<AppUser> getMe();
  Future<List<AppUser>> getUsers();
  Future<AppUser> updateRole(String userId, UserRole role);
}

class RemoteUserRepository implements UserRepository {
  const RemoteUserRepository(this.dataSource);

  final UserRemoteDataSource dataSource;

  @override
  Future<AppUser> getMe() => dataSource.getMe();

  @override
  Future<List<AppUser>> getUsers() => dataSource.getUsers();

  @override
  Future<AppUser> updateRole(String userId, UserRole role) =>
      dataSource.updateRole(userId, role);
}
