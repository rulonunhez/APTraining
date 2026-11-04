import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ap_training/features/auth/providers/auth_provider.dart';

import '../../../core/widgets/app_loader.dart';

class AuthLogoutButton extends ConsumerStatefulWidget {
  const AuthLogoutButton({super.key, this.asButton = false});

  final bool asButton;

  @override
  ConsumerState<AuthLogoutButton> createState() => _AuthLogoutButtonState();
}

class _AuthLogoutButtonState extends ConsumerState<AuthLogoutButton> {
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a iniciar sesión para entrar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final result = await ref.read(authProvider.notifier).logout();
      if (!result.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La sesión se cerró en este dispositivo, pero no se pudo revocar en el servidor.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoggingOut = authState.status == AuthStatus.loggingOut;
    final icon = isLoggingOut
        ? const SizedBox.square(
            dimension: 20,
            child: AppLoader(size: 20, color: Colors.black),
          )
        : const Icon(Icons.logout);

    if (widget.asButton) {
      return FilledButton.icon(
        onPressed: authState.isBusy ? null : _confirmLogout,
        icon: icon,
        label: const Text('Cerrar sesión'),
      );
    }

    return IconButton(
      tooltip: 'Cerrar sesión',
      onPressed: authState.isBusy ? null : _confirmLogout,
      icon: isLoggingOut ? icon : const Icon(Icons.logout),
    );
  }
}
