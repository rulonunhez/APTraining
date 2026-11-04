import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_loader.dart';
import '../../users/providers/users_providers.dart';
import '../widgets/auth_logout_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: currentUser.when(
            loading: () => const AppLoader(),
            error: (error, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se pudo cargar el perfil.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      ref.read(currentUserProvider.notifier).refresh(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
            data: (user) {
              if (user == null) {
                return const AppLoader();
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      user.username,
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.role.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/profile/workout-history'),
                    icon: const Icon(Icons.history),
                    label: const Text('Historial de entrenos'),
                  ),
                  const SizedBox(height: 12),
                  if (user.canManageGroups) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/profile/workout-history/users'),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Historial de usuarios'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (user.canManageGroups) ...[
                    OutlinedButton.icon(
                      onPressed: () => context.push('/profile/groups'),
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('Gestionar grupos'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (user.isAdmin) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/profile/manage-trainers'),
                      icon: const Icon(Icons.fitness_center_outlined),
                      label: const Text('Convertir en entrenador'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Opciones'),
                  ),
                  const SizedBox(height: 12),
                  AuthLogoutButton(asButton: true),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
