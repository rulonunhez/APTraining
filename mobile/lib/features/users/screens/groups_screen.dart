import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_loader.dart';
import '../../../shared/widgets/create_button.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/slidable_delete_action.dart';
import '../models/user_group.dart';
import '../providers/groups_provider.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar grupos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.read(groupsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: groupsAsync.maybeWhen(
        data: (_) => CreateButton(
          floating: true,
          onPressed: () => context.push('/profile/groups/create'),
        ),
        orElse: () => null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SearchField(
              initialValue: _search,
              onChanged: (value) => setState(() => _search = value),
            ),
            Expanded(
              child: groupsAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No se pudieron cargar los grupos'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(groupsProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                data: (groups) {
                  final query = _search.toLowerCase();
                  final filtered = groups
                      .where((group) =>
                          query.isEmpty ||
                          group.name.toLowerCase().contains(query))
                      .toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Center(
                          child: Text(
                            groups.isEmpty
                                ? 'Todavía no tienes grupos'
                                : 'No hay grupos que coincidan con la búsqueda',
                          ),
                        ),
                      ],
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(groupsProvider.notifier).refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _GroupTile(
                        group: filtered[index],
                        onTap: () => context.push(
                          '/profile/groups/${filtered[index].id}/edit',
                        ),
                        onDelete: () => _confirmDelete(filtered[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(UserGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text(
          'Se eliminará "${group.name}". Las planificaciones ya asignadas a '
          'sus miembros no se verán afectadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || group.id == null) return;
    try {
      await ref.read(groupsProvider.notifier).deleteGroup(group.id!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el grupo')),
        );
      }
    }
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.onTap,
    required this.onDelete,
  });

  final UserGroup group;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final memberCount = group.members.length;
    final membersLabel =
        memberCount == 1 ? '1 miembro' : '$memberCount miembros';

    return Slidable(
      key: ValueKey(group.id ?? group.name),
      closeOnScroll: true,
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.25,
        children: [
          SlidableDeleteAction(onPressed: onDelete),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          leading: Icon(Icons.groups_outlined, color: colors.primary),
          title: Text(
            group.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                membersLabel,
                if (group.description != null && group.description!.isNotEmpty)
                  group.description!,
                if (group.createdByUsername != null)
                  'Creado por ${group.createdByUsername}',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
