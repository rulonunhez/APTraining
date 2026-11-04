import 'package:flutter/material.dart';

import '../../core/widgets/app_loader.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: AppLoader(size: 112),
      ),
    );
  }
}
