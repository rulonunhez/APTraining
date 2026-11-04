import 'package:flutter/material.dart';

class AppLoader extends StatefulWidget {
  const AppLoader({
    this.size = 48,
    this.color,
    super.key,
  });

  final double size;
  final Color? color;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = ColorFiltered(
      colorFilter: ColorFilter.mode(
        widget.color ?? Theme.of(context).colorScheme.primary,
        BlendMode.srcIn,
      ),
      child: Image.asset(
        'assets/images/aptraining_mark.png',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      ),
    );

    return Semantics(
      label: 'Cargando',
      child: RotationTransition(
        turns: _controller,
        child: logo,
      ),
    );
  }
}
