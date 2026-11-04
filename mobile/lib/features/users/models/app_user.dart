enum UserRole {
  user,
  trainer,
  admin;

  String toApiValue() => name.toUpperCase();

  static UserRole fromApiValue(String? value) => value == null
      ? UserRole.user
      : UserRole.values.firstWhere(
          (role) => role.toApiValue() == value.toUpperCase(),
          orElse: () => UserRole.user,
        );

  String get label => switch (this) {
        UserRole.user => 'Usuario',
        UserRole.trainer => 'Entrenador',
        UserRole.admin => 'Admin',
      };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
  });

  final String id;
  final String username;
  final String email;
  final UserRole role;

  bool get isAdmin => role == UserRole.admin;
  bool get isTrainer => role == UserRole.trainer;
  bool get canManageGroups => isTrainer || isAdmin;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        role: UserRole.fromApiValue(json['role'] as String?),
      );
}
