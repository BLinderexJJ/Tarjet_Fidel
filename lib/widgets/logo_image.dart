import 'dart:convert';

import 'package:flutter/material.dart';

/// Muestra el logo del negocio desde una URL normal o desde una URL `data:`
/// con la imagen en base64 (plan Spark, sin Firebase Storage).
class LogoImage extends StatelessWidget {
  const LogoImage({
    super.key,
    required this.source,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final String source;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final value = source.trim();
    if (value.isEmpty) return fallback;

    if (value.startsWith('data:image/')) {
      final comma = value.indexOf(',');
      if (comma < 0) return fallback;
      try {
        final bytes = base64Decode(value.substring(comma + 1));
        return Image.memory(
          bytes,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }

    return Image.network(
      value,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
