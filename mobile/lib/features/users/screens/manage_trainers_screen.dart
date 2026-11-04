import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_loader.dart';
import '../../../shared/widgets/search_field.dart';
import '../data/user_remote_data_source.dart';
import '../models/app_user.dart';
import '../providers/users_providers.dart';
import '../widgets/user_tile.dart';

/// Pantalla de administración para cambiar el rol de los usuarios
/// (usuario <-> entrenador). Solo accesible para el admin.
class ManageTrainersScreen extends ConsumerStatefulWidget {
  const ManageTrainersScreen({super.key});

  @override
  ConsumerState<ManageTrainersScreen> createState() =>
      _ManageTrainersScreenState();
}

class _ManageTrainersScreenState extends ConsumerState<ManageTrainersScreen> {
  String _search = '';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Convertir en entrenador')),
      body: SafeArea(
        child: Column(
          children: [
            SearchField(
              initialValue: _search,
              onChanged: (value) => setState(() => _search = value),
            ),
            Expanded(
              child: usersAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No se pudieron cargar los usuarios'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(usersProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                data: (users) {
                  final query = _search.toLowerCase();
                  final visible = users
                      .where((user) => user.id != currentUserId)
                      .where((user) =>
                          query.isEmpty ||
                          user.username.toLowerCase().contains(query) ||
                          user.email.toLowerCase().contains(query))
                      .toList()
                    ..sort((a, b) => a.username
                        .toLowerCase()
                        .compareTo(b.username.toLowerCase()));

                  if (visible.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: const [
                        Center(child: Text('No hay usuarios que coincidan')),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = visible[index];
                      return UserTile(
                        user: user,
                        onTap: _busy ? null : () => _confirmRoleChange(user),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRoleChange(AppUser user) async {
    // El rol admin no se gestiona desde la app
    if (user.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El rol de administrador no se puede cambiar aquí'),
        ),
      );
      return;
    }

    final promote = !user.isTrainer;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          promote ? 'Convertir en entrenador' : 'Quitar rol de entrenador',
        ),
        content: Text(
          promote
              ? '${user.username} pasará a ser entrenador: podrá gestionar '
                  'grupos y asignar planificaciones a otros usuarios.'
              : '${user.username} volverá a ser usuario: perderá el acceso a '
                  'la gestión de grupos y al listado de usuarios. Las '
                  'planificaciones que ya asignó no se verán afectadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(promote ? 'Convertir' : 'Quitar rol'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(usersProvider.notifier).updateRole(
            user.id,
            promote ? UserRole.trainer : UserRole.user,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              promote
                  ? '${user.username} ahora es entrenador'
                  : '${user.username} vuelve a ser usuario',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        final serverMessage = error is UserApiException ? error.message : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(serverMessage ?? 'No se pudo cambiar el rol'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
