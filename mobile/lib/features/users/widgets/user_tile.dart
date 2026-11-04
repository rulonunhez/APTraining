import 'package:flutter/material.dart';

import '../models/app_user.dart';

/// Tarjeta de usuario con el espacio reservado a la izquierda para la
/// futura foto de perfil.
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
    final colors = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: colors.surfaceContainerHighest,
          child: Icon(Icons.person_outline, color: colors.onSurfaceVariant),
        ),
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
