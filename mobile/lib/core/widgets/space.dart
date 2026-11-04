import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class VSpace extends StatelessWidget {
  final double size;
  const VSpace.sm({super.key}) : size = AppSpacing.sm;
  const VSpace.md({super.key}) : size = AppSpacing.md;
  const VSpace.lg({super.key}) : size = AppSpacing.lg;
  const VSpace.xl({super.key}) : size = AppSpacing.xl;
  const VSpace.custom(this.size, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(height: size);
}

class HSpace extends StatelessWidget {
  final double size;
  const HSpace.sm({super.key}) : size = AppSpacing.sm;
  const HSpace.md({super.key}) : size = AppSpacing.md;
  const HSpace.lg({super.key}) : size = AppSpacing.lg;
  const HSpace.xl({super.key}) : size = AppSpacing.xl;
  const HSpace.custom(this.size, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(width: size);
}