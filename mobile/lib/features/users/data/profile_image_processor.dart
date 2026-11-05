import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Excepción lanzada cuando la imagen elegida no se puede decodificar.
class ProfileImageFormatException implements Exception {
  const ProfileImageFormatException();

  @override
  String toString() => 'Formato de imagen no soportado';
}

/// Recorta la foto de perfil a un cuadrado centrado y la redimensiona
/// antes de subirla, para ahorrar ancho de banda y almacenamiento.
class ProfileImageProcessor {
  const ProfileImageProcessor();

  static const maxDimension = 512;
  static const jpegQuality = 85;
  static const outputContentType = 'image/jpeg';

  Future<File?> pickAndProcess(ImageSource source) async {
    // imageQuality fuerza salida JPEG en Android/iOS, cubriendo formatos
    // como HEIC que el paquete image no decodifica.
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 95);
    if (picked == null) return null;
    return process(File(picked.path));
  }

  Future<File> process(File raw) async {
    final decoded = img.decodeImage(await raw.readAsBytes());
    if (decoded == null) {
      throw const ProfileImageFormatException();
    }

    final side = min(decoded.width, decoded.height);
    var square = img.copyCrop(
      decoded,
      x: (decoded.width - side) ~/ 2,
      y: (decoded.height - side) ~/ 2,
      width: side,
      height: side,
    );
    if (side > maxDimension) {
      square = img.copyResize(square, width: maxDimension, height: maxDimension);
    }

    final dir = await getTemporaryDirectory();
    final output = File(
      '${dir.path}/profile_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await output.writeAsBytes(
      img.encodeJpg(square, quality: jpegQuality),
      flush: true,
    );
    return output;
  }
}
