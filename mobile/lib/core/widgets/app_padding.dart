import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class AppPadding extends StatelessWidget {
  final Widget child;
  final double horizontal;
  final double vertical;

  const AppPadding({
    super.key,
    required this.child,
    this.horizontal = AppSpacing.md,
    this.vertical = AppSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      child: child,
    );
  }
}