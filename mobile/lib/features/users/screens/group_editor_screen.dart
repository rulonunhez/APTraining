import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_loader.dart';
import '../data/group_remote_data_source.dart';
import '../models/app_user.dart';
import '../models/user_group.dart';
import '../providers/groups_provider.dart';
import '../providers/users_providers.dart';
import '../widgets/user_tile.dart';
import 'user_picker_screen.dart';

class GroupEditorScreen extends ConsumerStatefulWidget {
  const GroupEditorScreen({super.key, this.groupId});

  final String? groupId;

  bool get isEditing => groupId != null;

  @override
  ConsumerState<GroupEditorScreen> createState() => _GroupEditorScreenState();
}

class _GroupEditorScreenState extends ConsumerState<GroupEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<AppUser> _members = const [];
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      _initialize(null);
      return _buildScaffold(context);
    }

    final groupsAsync = ref.watch(groupsProvider);
    return groupsAsync.when(
      loading: () => const Scaffold(body: Center(child: AppLoader())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Editar grupo')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudo cargar el grupo'),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.read(groupsProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: (groups) {
        final group = groups
            .where((candidate) => candidate.id == widget.groupId)
            .firstOrNull;
        if (group == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Editar grupo')),
            body: const Center(child: Text('El grupo ya no existe')),
          );
        }
        _initialize(group);
        return _buildScaffold(context);
      },
    );
  }

  void _initialize(UserGroup? group) {
    if (_initialized) return;
    _initialized = true;
    if (group != null) {
      _nameController.text = group.name;
      _descriptionController.text = group.description ?? '';
      _members = group.members;
    }
  }

  Widget _buildScaffold(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar grupo' : 'Crear grupo'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Grupo mañanas',
                ),
                maxLength: 255,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'El nombre es obligatorio'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Ej. Usuarios del turno de mañana',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Miembros (${_members.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickMembers,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Añadir'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_members.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Sin miembros. Añade usuarios al grupo.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final member in _members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: UserTile(
                      user: member,
                      trailing: IconButton(
                        tooltip: 'Quitar del grupo',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() {
                          _members = _members
                              .where((user) => user.id != member.id)
                              .toList();
                        }),
                      ),
                    ),
                  ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(widget.isEditing ? 'Guardar cambios' : 'Crear grupo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMembers() async {
    // El entrenador no es miembro de sus propios grupos: no se ofrece.
    final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
    final selected = await Navigator.of(context).push<List<AppUser>>(
      MaterialPageRoute(
        builder: (_) => UserPickerScreen(
          initialSelected: _members,
          excludedUserIds: {if (currentUserId != null) currentUserId},
          title: 'Miembros del grupo',
        ),
      ),
    );
    if (selected != null) {
      setState(() => _members = selected);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Al editar, el usuario debe confirmar: los cambios de miembros no
    // modifican las asignaciones ya materializadas.
    if (widget.isEditing) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Guardar cambios del grupo'),
          content: const Text(
            'Los cambios en los miembros no modifican las planificaciones ya '
            'asignadas: quitar a alguien del grupo no le quita sus planes, y '
            'los miembros nuevos no reciben los planes del grupo '
            'automáticamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Entendido, guardar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _saving = true);
    final group = UserGroup(
      id: widget.groupId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      members: _members,
    );

    try {
      final notifier = ref.read(groupsProvider.notifier);
      if (widget.isEditing) {
        await notifier.updateGroup(widget.groupId!, group);
      } else {
        await notifier.createGroup(group);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        final serverMessage = error is GroupApiException ? error.message : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(serverMessage ?? 'No se pudo guardar el grupo'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Tras editar, ofrece sincronizar las planificaciones del grupo con
    // sus miembros actuales (operación aditiva, nunca quita asignaciones).
    if (widget.isEditing) {
      final sync = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sincronizar planificaciones'),
          content: const Text(
            '¿Quieres asignar a los miembros actuales del grupo las '
            'planificaciones que se asignaron a través de este grupo? '
            'Solo se añaden asignaciones que falten; no se quita ninguna.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sincronizar'),
            ),
          ],
        ),
      );

      if (sync == true && mounted) {
        try {
          final created = await ref
              .read(groupsProvider.notifier)
              .syncAssignments(widget.groupId!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  created == 0
                      ? 'Los miembros ya tenían todas las planificaciones'
                      : 'Se crearon $created asignaciones nuevas',
                ),
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudieron sincronizar las planificaciones'),
              ),
            );
          }
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
