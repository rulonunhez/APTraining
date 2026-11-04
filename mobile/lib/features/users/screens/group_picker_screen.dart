import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_loader.dart';
import '../../../shared/widgets/search_field.dart';
import '../models/user_group.dart';
import '../providers/groups_provider.dart';

/// Selector múltiple de grupos con búsqueda. Devuelve la lista de grupos
/// seleccionados mediante `Navigator.pop`.
class GroupPickerScreen extends ConsumerStatefulWidget {
  const GroupPickerScreen({
    super.key,
    this.initialSelected = const [],
    this.title = 'Seleccionar grupos',
  });

  final List<UserGroup> initialSelected;
  final String title;

  @override
  ConsumerState<GroupPickerScreen> createState() => _GroupPickerScreenState();
}

class _GroupPickerScreenState extends ConsumerState<GroupPickerScreen> {
  late final Map<String, UserGroup> _selected = {
    for (final group in widget.initialSelected)
      if (group.id != null) group.id!: group,
  };
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, _selected.values.toList()),
            icon: const Icon(Icons.check),
            label: Text('Listo (${_selected.length})'),
          ),
        ],
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
                  final visible = groups
                      .where((group) =>
                          query.isEmpty ||
                          group.name.toLowerCase().contains(query))
                      .toList();

                  if (visible.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Center(
                          child: Text(
                            groups.isEmpty
                                ? 'No tienes grupos creados'
                                : 'No hay grupos que coincidan',
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final group = visible[index];
                      final isSelected = _selected.containsKey(group.id);
                      final memberCount = group.members.length;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Icon(
                            Icons.groups_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            memberCount == 1
                                ? '1 miembro'
                                : '$memberCount miembros',
                          ),
                          trailing: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selected.remove(group.id);
                            } else {
                              _selected[group.id!] = group;
                            }
                          }),
                        ),
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
}
