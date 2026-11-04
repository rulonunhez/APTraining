import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ap_training/core/widgets/app_loader.dart';
import 'package:go_router/go_router.dart';
import 'package:ap_training/features/auth/providers/auth_provider.dart';
import 'package:ap_training/features/auth/screens/auth_form_shell.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _passwordVisible = false;
  bool _registered = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authProvider).isBusy ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _error = null);

    try {
      final result = await ref.read(authProvider.notifier).register(
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      if (result.isSuccess) {
        setState(() => _registered = true);
      } else {
        setState(() => _error = result.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'No se pudo crear la cuenta. Comprueba tu conexión e inténtalo de nuevo.');
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

  Widget _passwordVisibilityButton() => IconButton(
        tooltip:
            _passwordVisible ? 'Ocultar contraseñas' : 'Mostrar contraseñas',
        onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
        icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility),
      );

  @override
  Widget build(BuildContext context) {
    final isBusy = ref.watch(authProvider).isBusy;
    if (_registered) {
      return AuthFormShell(
        title: 'Cuenta creada',
        subtitle: 'Tu registro se completó correctamente.',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthMessageBanner(
              message: 'Ya puedes iniciar sesión con tu nueva cuenta.',
              isError: false,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/login'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              icon: const Icon(Icons.login),
              label: const Text('Ir a iniciar sesión'),
            ),
          ],
        ),
      );
    }

    return AuthFormShell(
      title: 'Crea tu cuenta',
      subtitle: 'Introduce tus datos para empezar.',
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
              key: const Key('register-username'),
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Introduce un nombre de usuario.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Nombre de usuario',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register-email'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: _validateEmail,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register-password'),
              controller: _passwordController,
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) => value == null || value.isEmpty
                  ? 'Introduce una contraseña.'
                  : null,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: _passwordVisibilityButton(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register-confirm-password'),
              controller: _confirmationController,
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirma tu contraseña.';
                }
                if (value != _passwordController.text) {
                  return 'Las contraseñas no coinciden.';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: _passwordVisibilityButton(),
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
                  : const Text('Crear cuenta'),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: isBusy ? null : () => context.go('/login'),
                child: const Text('Ya tengo una cuenta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
