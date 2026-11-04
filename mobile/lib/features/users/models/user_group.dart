import 'app_user.dart';

class UserGroup {
  const UserGroup({
    this.id,
    required this.name,
    this.description,
    this.members = const [],
    this.createdByUsername,
  });

  final String? id;
  final String name;
  final String? description;
  final List<AppUser> members;
  final String? createdByUsername;

  UserGroup copyWith({
    String? name,
    String? description,
    List<AppUser>? members,
  }) =>
      UserGroup(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        members: members ?? this.members,
        createdByUsername: createdByUsername,
      );

  factory UserGroup.fromJson(Map<String, dynamic> json) => UserGroup(
        id: json['id'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        members: (json['members'] as List<dynamic>? ?? const [])
            .map((item) => AppUser.fromJson(item as Map<String, dynamic>))
            .toList(),
        createdByUsername: json['createdByUsername'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'memberIds': members.map((member) => member.id).toList(),
      };
}
