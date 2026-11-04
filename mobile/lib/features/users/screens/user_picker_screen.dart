import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_loader.dart';
import '../../../shared/widgets/search_field.dart';
import '../models/app_user.dart';
import '../providers/users_providers.dart';
import '../widgets/user_tile.dart';

/// Selector múltiple de usuarios con búsqueda. Devuelve la lista de
/// usuarios seleccionados mediante `Navigator.pop`.
/// Con [singleSelection] solo se puede tener un usuario seleccionado.
class UserPickerScreen extends ConsumerStatefulWidget {
  const UserPickerScreen({
    super.key,
    this.initialSelected = const [],
    this.excludedUserIds = const {},
    this.title = 'Seleccionar usuarios',
    this.singleSelection = false,
  });

  final List<AppUser> initialSelected;
  final Set<String> excludedUserIds;
  final String title;
  final bool singleSelection;

  @override
  ConsumerState<UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends ConsumerState<UserPickerScreen> {
  late final Map<String, AppUser> _selected = {
    for (final user in widget.initialSelected) user.id: user,
  };
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

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
                      .where(
                          (user) => !widget.excludedUserIds.contains(user.id))
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
                      final isSelected = _selected.containsKey(user.id);
                      return UserTile(
                        user: user,
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selected.remove(user.id);
                          } else if (widget.singleSelection) {
                            _selected
                              ..clear()
                              ..[user.id] = user;
                          } else {
                            _selected[user.id] = user;
                          }
                        }),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
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
