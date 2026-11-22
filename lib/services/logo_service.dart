import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

import '../app_config.dart';

/// Selecciona imágenes del negocio y las convierte en URL `data:`.
///
/// En el plan Spark no hay Firebase Storage, así que el logo y la imagen del
/// sello se guardan como base64 dentro de `config/main`. Firestore limita cada
/// documento a 1 MiB, por lo que las imágenes se reducen antes de guardarse y
/// se rechazan si siguen siendo demasiado grandes.
class LogoService {
  /// Selecciona el logo del negocio (hasta 512 px y 600 KB).
  Future<String?> pickLogoAsDataUri() {
    return _pickImageAsDataUri(
      dialogTitle: 'Selecciona el logo del negocio',
      maxInputBytes: AppConfig.maxLogoInputBytes,
      maxInputMb: AppConfig.maxLogoInputMb,
      maxDataUriBytes: AppConfig.maxLogoDataUriBytes,
      resizeWidth: 512,
      tooLargeMessage:
          'La imagen es demasiado grande incluso después de reducirla. '
          'Usa un logo más pequeño (máx. 600 KB).',
    );
  }

  /// Selecciona la imagen que se muestra dentro de cada sello válido.
  ///
  /// Se reduce más que el logo porque solo se ve a unos 50 px en pantalla.
  Future<String?> pickStampImageAsDataUri() {
    return _pickImageAsDataUri(
      dialogTitle: 'Selecciona la imagen del sello',
      maxInputBytes: AppConfig.maxStampImageInputBytes,
      maxInputMb: AppConfig.maxStampImageInputMb,
      maxDataUriBytes: AppConfig.maxStampImageDataUriBytes,
      resizeWidth: AppConfig.stampImageResizeWidth,
      tooLargeMessage:
          'La imagen del sello es demasiado grande incluso después de '
          'reducirla. Usa una imagen más pequeña (máx. 160 KB).',
    );
  }

  Future<String?> _pickImageAsDataUri({
    required String dialogTitle,
    required int maxInputBytes,
    required int maxInputMb,
    required int maxDataUriBytes,
    required int resizeWidth,
    required String tooLargeMessage,
  }) async {
    final file = await FilePicker.pickFile(
      dialogTitle: dialogTitle,
      type: FileType.image,
    );

    if (file == null) return null;

    final length = await file.length();
    if (length != null && length > maxInputBytes) {
      throw StateError('La imagen supera el límite de $maxInputMb MB.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('No se pudo leer la imagen seleccionada.');
    }
    if (bytes.length > maxInputBytes) {
      throw StateError('La imagen supera el límite de $maxInputMb MB.');
    }

    final extension = (file.extension ?? 'png').toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/png',
    };

    if (bytes.length <= maxDataUriBytes) {
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    }

    final resized = await _resizeToPng(bytes, maxWidth: resizeWidth);
    if (resized == null || resized.length > maxDataUriBytes) {
      throw StateError(tooLargeMessage);
    }

    return 'data:image/png;base64,${base64Encode(resized)}';
  }

  Future<Uint8List?> _resizeToPng(
    Uint8List bytes, {
    required int maxWidth,
  }) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(bytes, targetWidth: maxWidth);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}
