import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ap_training/core/widgets/app_loader.dart';
import 'package:go_router/go_router.dart';
import 'package:ap_training/features/auth/providers/auth_provider.dart';
import 'package:ap_training/features/auth/screens/auth_form_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authProvider).isBusy ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _error = null);

    try {
      final result = await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (!mounted) return;
      if (!result.isSuccess) setState(() => _error = result.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'No se pudo iniciar sesión. Comprueba tu conexión e inténtalo de nuevo.');
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Introduce tu correo electrónico.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Introduce un correo electrónico válido.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = ref.watch(authProvider).isBusy;
    return AuthFormShell(
      title: 'Bienvenido de nuevo',
      subtitle: 'Inicia sesión para continuar con tu entrenamiento.',
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AuthMessageBanner(message: _error!, isError: true),
              const SizedBox(height: 18),
            ],
            TextFormField(
              key: const Key('login-email'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email
              ],
              validator: _validateEmail,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('login-password'),
              controller: _passwordController,
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              validator: (value) => value == null || value.isEmpty
                  ? 'Introduce tu contraseña.'
                  : null,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _passwordVisible
                      ? 'Ocultar contraseña'
                      : 'Mostrar contraseña',
                  onPressed: () => setState(
                    () => _passwordVisible = !_passwordVisible,
                  ),
                  icon: Icon(
                    _passwordVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isBusy ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: isBusy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: AppLoader(size: 22, color: Colors.white),
                    )
                  : const Text('Iniciar sesión'),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: isBusy ? null : () => context.go('/register'),
                child: const Text('Crear una cuenta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
