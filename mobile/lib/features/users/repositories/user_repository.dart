import 'dart:io';

import '../../../core/client/api_client.dart';
import '../data/user_remote_data_source.dart';
import '../models/app_user.dart';

abstract interface class UserRepository {
  Future<AppUser> getMe();
  Future<List<AppUser>> getUsers();
  Future<AppUser> updateRole(String userId, UserRole role);
  Future<AppUser> updateProfileImage(File image, String contentType);
  Future<AppUser> deleteProfileImage();
}

class RemoteUserRepository implements UserRepository {
  const RemoteUserRepository(this.dataSource, this.apiClient);

  final UserRemoteDataSource dataSource;
  final ApiClient apiClient;

  @override
  Future<AppUser> getMe() => dataSource.getMe();

  @override
  Future<List<AppUser>> getUsers() => dataSource.getUsers();

  @override
  Future<AppUser> updateRole(String userId, UserRole role) =>
      dataSource.updateRole(userId, role);

  // La imagen se sube directa a S3 con una URL prefirmada; el backend solo
  // recibe la clave del objeto, igual que con los vídeos de los ejercicios.
  @override
  Future<AppUser> updateProfileImage(File image, String contentType) async {
    final uploadUrl = await dataSource.createProfileImageUploadUrl(
      contentType: contentType,
      sizeBytes: await image.length(),
    );
    final uploadResponse = await apiClient.putFileToUrl(
      uploadUrl.uploadUrl,
      image,
      contentType: uploadUrl.contentType,
    );
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw UserApiException(
        'direct-profile-image-upload',
        uploadResponse.statusCode,
        message: 'No se pudo subir la imagen',
      );
    }
    return dataSource.updateProfileImage(uploadUrl.key);
  }

  @override
  Future<AppUser> deleteProfileImage() => dataSource.deleteProfileImage();
}
