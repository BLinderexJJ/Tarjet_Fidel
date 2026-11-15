import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_config.dart';

/// Muestra el QR de check-in del negocio.
class QrDisplay extends StatelessWidget {
  const QrDisplay({
    super.key,
    required this.code,
    this.size = 260,
    this.color = const Color(0xFF4F46E5),
  });

  final String code;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (code.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Genera un código de check-in para mostrar el QR.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: QrImageView(
        data: '${AppConfig.qrPrefix}$code',
        version: QrVersions.auto,
        size: size,
        backgroundColor: Colors.white,
        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: color,
        ),
      ),
    );
  }
}
