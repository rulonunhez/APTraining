import 'package:flutter/material.dart';

import '../models/app_user.dart';
import 'user_avatar.dart';

/// Tarjeta de usuario con su foto de perfil a la izquierda.
class UserTile extends StatelessWidget {
  const UserTile({
    super.key,
    required this.user,
    this.onTap,
    this.trailing,
    this.showRole = true,
  });

  final AppUser user;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showRole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        leading: UserAvatar(user: user),
        title: Text(
          user.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          user.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        trailing: trailing ??
            (showRole
                ? Chip(
                    label: Text(user.role.label),
                    labelStyle: theme.textTheme.labelSmall,
                    visualDensity: VisualDensity.compact,
                  )
                : null),
      ),
    );
  }
}
