import 'package:flutter/material.dart';

/// Campo de búsqueda con estado propio. [initialValue] permite restaurar el
/// texto cuando el widget se recrea (por ejemplo, tras volver de una pantalla
/// de creación que invalida el listado), para que lo visible coincida con el
/// filtro que sigue aplicado en la pantalla.
class SearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String initialValue;

  const SearchField({
    super.key,
    required this.onChanged,
    this.initialValue = '',
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: "Buscar...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
