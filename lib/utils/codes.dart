import 'dart:math';

import '../app_config.dart';

/// Extrae el código de check-in de un QR.
///
/// Acepta el payload `TARJET:XXXX`, una URL con `?code=XXXX` o el código
/// directamente (útil para la entrada manual).
String normalizeCheckinCode(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return '';

  final lower = value.toLowerCase();
  final prefix = AppConfig.qrPrefix.toLowerCase();
  if (lower.startsWith(prefix)) {
    value = value.substring(prefix.length).trim();
  }

  final uri = Uri.tryParse(value);
  if (uri != null && uri.queryParameters.containsKey('code')) {
    value = (uri.queryParameters['code'] ?? '').trim();
  }

  return value.toUpperCase();
}

/// Genera un código de check-in aleatorio sin caracteres ambiguos.
String generateCheckinCode({int length = 6}) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}
