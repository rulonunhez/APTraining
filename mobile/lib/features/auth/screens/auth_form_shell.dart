import 'package:flutter/material.dart';

class AuthFormShell extends StatelessWidget {
  const AuthFormShell({
    required this.title,
    required this.subtitle,
    required this.body,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360 ? 20.0 : 28.0;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 30,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.asset(
                            'assets/images/aptraining_logo.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      body,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    required this.message,
    required this.isError,
    super.key,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final background =
        isError ? const Color(0xFFFFE9E6) : const Color(0xFFE6F1E9);
    final foreground =
        isError ? const Color(0xFF8E2D23) : const Color(0xFF24583B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: foreground,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: foreground))),
        ],
      ),
    );
  }
}
