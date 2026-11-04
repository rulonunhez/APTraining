import 'dart:convert';

/// Extrae el mensaje de error que devuelve el backend en el cuerpo de las
/// respuestas de error (`{"error": "...", "requestId": "..."}`).
/// Devuelve null si el cuerpo no es JSON o no trae mensaje.
String? apiErrorMessage(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final message = decoded['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
  } on FormatException {
    return null;
  }
  return null;
}
