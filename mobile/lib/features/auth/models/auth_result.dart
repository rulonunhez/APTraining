enum AuthFailure {
  invalidCredentials,
  accountAlreadyExists,
  invalidInput,
  networkUnavailable,
  serviceUnavailable,
  invalidResponse,
  remoteLogoutFailed,
  localSessionCleanupFailed,
}

class AuthResult {
  const AuthResult.success() : failure = null;
  const AuthResult.failure(this.failure);

  final AuthFailure? failure;

  bool get isSuccess => failure == null;

  String get message => switch (failure) {
        null => '',
        AuthFailure.invalidCredentials => 'Correo o contraseña incorrectos.',
        AuthFailure.accountAlreadyExists =>
          'Ya existe una cuenta con esos datos.',
        AuthFailure.invalidInput => 'Revisa los datos introducidos.',
        AuthFailure.networkUnavailable =>
          'No se pudo conectar. Comprueba tu conexión e inténtalo de nuevo.',
        AuthFailure.serviceUnavailable =>
          'El servicio no está disponible. Inténtalo de nuevo más tarde.',
        AuthFailure.invalidResponse =>
          'El servidor devolvió una respuesta no válida.',
        AuthFailure.remoteLogoutFailed =>
          'La sesión se cerró en este dispositivo, pero no se pudo revocar en el servidor.',
        AuthFailure.localSessionCleanupFailed =>
          'No se pudieron borrar las credenciales guardadas en este dispositivo.',
      };
}
