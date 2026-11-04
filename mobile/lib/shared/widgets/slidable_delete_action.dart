import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class SlidableDeleteAction extends StatelessWidget {
  const SlidableDeleteAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      padding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, color: Colors.white, size: 26),
                SizedBox(height: 4),
                Text(
                  'Borrar',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
