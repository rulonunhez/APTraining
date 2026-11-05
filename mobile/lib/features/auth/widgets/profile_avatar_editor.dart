import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../users/data/profile_image_processor.dart';
import '../../users/models/app_user.dart';
import '../../users/providers/users_providers.dart';
import '../../users/widgets/user_avatar.dart';

/// Avatar grande del perfil con un botón para cambiar o quitar la foto.
class ProfileAvatarEditor extends ConsumerStatefulWidget {
  const ProfileAvatarEditor({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<ProfileAvatarEditor> createState() =>
      _ProfileAvatarEditorState();
}

class _ProfileAvatarEditorState extends ConsumerState<ProfileAvatarEditor> {
  bool _busy = false;

  Future<void> _openOptions() async {
    if (_busy) return;
    final hasPhoto = widget.user.profileImageUrl != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(sheetContext).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Hacer una foto'),
              onTap: () => Navigator.of(sheetContext).pop('camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: Text(
                  'Quitar foto',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'gallery':
        await _changePhoto(ImageSource.gallery);
      case 'camera':
        await _changePhoto(ImageSource.camera);
      case 'delete':
        await _removePhoto();
    }
  }

  Future<void> _changePhoto(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final file = await const ProfileImageProcessor().pickAndProcess(source);
      if (file == null) return;
      try {
        await ref.read(currentUserProvider.notifier).changeProfileImage(file);
      } finally {
        // El archivo temporal ya no hace falta tras la subida.
        if (file.existsSync()) await file.delete();
      }
    } on ProfileImageFormatException {
      _showMessage('Ese formato de imagen no está soportado');
    } catch (_) {
      _showMessage('No se pudo actualizar la foto de perfil');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _busy = true);
    try {
      await ref.read(currentUserProvider.notifier).removeProfileImage();
    } catch (_) {
      _showMessage('No se pudo quitar la foto de perfil');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 4000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Observa el usuario actual para reflejar la foto recién subida.
    final user = ref.watch(currentUserProvider).valueOrNull ?? widget.user;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        UserAvatar(user: user, radius: 48),
        if (_busy)
          const Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          ),
        Material(
          shape: const CircleBorder(),
          color: colors.primary,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _busy ? null : _openOptions,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.edit,
                size: 16,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
