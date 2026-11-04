import 'package:flutter/material.dart';

import 'floating_nav_metrics.dart';

class CreateButton extends StatelessWidget {
  const CreateButton({
    super.key,
    required this.onPressed,
    this.floating = false,
  });

  final VoidCallback onPressed;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    if (floating) {
      return FloatingActionButton.extended(
        heroTag: null,
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: const Text('Crear'),
      );
    }

    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: const Text('Crear'),
    );
  }
}

class CreateButtonLocation extends FloatingActionButtonLocation {
  const CreateButtonLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final defaultOffset =
        FloatingActionButtonLocation.endFloat.getOffset(geometry);
    // El menú flotante se apoya sobre el área segura (gestos del sistema),
    // así que el botón debe subir también ese inset para no quedar tapado.
    return defaultOffset.translate(
      0,
      -(16 +
          floatingNavBarHeight +
          floatingNavBarBottomMargin +
          geometry.minInsets.bottom),
    );
  }
}
