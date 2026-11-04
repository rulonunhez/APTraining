import 'package:flutter/material.dart';

import '../models/exercise_catalogs.dart';

class ExerciseSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool required;
  final Widget child;

  const ExerciseSectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.required = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  radius: 18,
                  child: Icon(icon, color: scheme.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  required ? 'Obligatorio' : 'Opcional',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: required ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class ExerciseMultiSelectChips extends StatelessWidget {
  final List<CatalogItem> items;
  final Set<String> selectedIds;
  final void Function(String id, bool isSelected) onToggle;

  const ExerciseMultiSelectChips({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'Sin datos disponibles',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: items.map((item) {
        final isSelected = selectedIds.contains(item.id);
        return FilterChip(
          label: Text(item.name, style: const TextStyle(fontSize: 12)),
          selected: isSelected,
          onSelected: (_) => onToggle(item.id, isSelected),
        );
      }).toList(),
    );
  }
}

class ExerciseTextArea extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const ExerciseTextArea({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 4,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(hintText: hint),
    );
  }
}
