import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';

/// Avatar circular con la foto de perfil del usuario, o un icono de
/// respaldo si no tiene foto o no se puede cargar.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 22,
  });

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = user.profileImageUrl;

    Widget fallback() => CircleAvatar(
          radius: radius,
          backgroundColor: colors.surfaceContainerHighest,
          child: Icon(
            Icons.person_outline,
            color: colors.onSurfaceVariant,
            size: radius * 1.15,
          ),
        );

    if (url == null) return fallback();

    return CachedNetworkImage(
      imageUrl: url,
      // Decodifica la imagen al tamaño mostrado para no cargarla entera.
      memCacheWidth: (radius * 2 * MediaQuery.devicePixelRatioOf(context)).round(),
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundColor: colors.surfaceContainerHighest,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, _) => fallback(),
      errorWidget: (context, _, __) => fallback(),
    );
  }
}
