import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/floating_nav_metrics.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.branchIndex, this.icon, this.activeIcon, this.label);

  final int branchIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

// Orden visual; branchIndex es el índice real de la rama en el router.
const _items = [
  _NavItem(0, Icons.calendar_today_outlined, Icons.calendar_today, 'Planificación'),
  _NavItem(2, Icons.fitness_center_outlined, Icons.fitness_center, 'Entrenamientos'),
  _NavItem(1, Icons.play_arrow_rounded, Icons.play_arrow_rounded, 'Workout'),
  _NavItem(3, Icons.list_outlined, Icons.list, 'Ejercicios'),
  _NavItem(4, Icons.person_outline, Icons.person, 'Perfil'),
];

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          20,
          0,
          20,
          floatingNavBarBottomMargin,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: floatingNavBarHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.navigationSurface,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: const Color(0xFF292930)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final item in _items)
                    item.branchIndex == 1
                        ? _CenterButton(
                            item: item,
                            selected: currentIndex == item.branchIndex,
                            onTap: () => onSelected(item.branchIndex),
                          )
                        : _NavButton(
                            item: item,
                            selected: currentIndex == item.branchIndex,
                            onTap: () => onSelected(item.branchIndex),
                          ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.label,
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? AppColors.purpleLight : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? AppColors.purple : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Icon(
            selected ? item.activeIcon : item.icon,
            color: selected ? AppColors.purple : AppColors.gray,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.label,
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent,
            border: selected
                ? Border.all(color: Colors.white, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.45),
                blurRadius: 12,
              ),
            ],
          ),
          child: Icon(item.icon, color: AppColors.ink, size: 32),
        ),
      ),
    );
  }
}
