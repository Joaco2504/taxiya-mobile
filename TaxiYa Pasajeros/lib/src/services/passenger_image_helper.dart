import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Selecciona y comprime fotos de perfil del pasajero antes de subirlas.
abstract final class PassengerImageHelper {
  static final ImagePicker _picker = ImagePicker();

  static Future<Uint8List?> pickAndCompress(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (file == null) return null;

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: 900,
        minHeight: 900,
        quality: 75,
        format: CompressFormat.jpeg,
      );
      if (compressed != null && compressed.isNotEmpty) {
        return compressed;
      }
    }

    return file.readAsBytes();
  }
}
