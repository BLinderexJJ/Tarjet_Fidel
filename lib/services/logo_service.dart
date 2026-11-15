import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

import '../app_config.dart';

/// Selecciona el logo del negocio y lo convierte en una URL `data:`.
///
/// En el plan Spark no hay Firebase Storage, así que la imagen se guarda como
/// base64 dentro de `config/main.logoUrl`. Firestore limita cada documento a
/// 1 MiB, por lo que la imagen se reduce a un máximo de 512 px de ancho y se
/// rechaza si sigue siendo demasiado grande.
class LogoService {
  Future<String?> pickLogoAsDataUri() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Selecciona el logo del negocio',
      type: FileType.image,
    );

    if (file == null) return null;

    final length = await file.length();
    if (length != null && length > AppConfig.maxLogoInputBytes) {
      throw StateError(
        'La imagen supera el límite de ${AppConfig.maxLogoInputMb} MB.',
      );
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('No se pudo leer la imagen seleccionada.');
    }
    if (bytes.length > AppConfig.maxLogoInputBytes) {
      throw StateError(
        'La imagen supera el límite de ${AppConfig.maxLogoInputMb} MB.',
      );
    }

    final extension = (file.extension ?? 'png').toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/png',
    };

    if (bytes.length <= AppConfig.maxLogoDataUriBytes) {
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    }

    final resized = await _resizeToPng(bytes, maxWidth: 512);
    if (resized == null || resized.length > AppConfig.maxLogoDataUriBytes) {
      throw StateError(
        'La imagen es demasiado grande incluso después de reducirla. '
        'Usa un logo más pequeño (máx. 600 KB).',
      );
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
