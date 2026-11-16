import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Convierte la cadena ISO de `config/main.trialExpiryDate` en una fecha UTC.
DateTime? parseTrialExpiry(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}

/// Obtiene la fecha de prueba desde un mapa de Firestore.
///
/// Prefiere `trialExpiryAt` (Timestamp, el campo que usan las reglas) y cae en
/// `trialExpiryDate` (cadena ISO) para configuraciones antiguas.
DateTime? trialExpiryFromMap(Map<String, dynamic> data) {
  final timestamp = data['trialExpiryAt'];
  if (timestamp is Timestamp) return timestamp.toDate().toUtc();

  final rawDate = data['trialExpiryDate'];
  return parseTrialExpiry(rawDate is String ? rawDate : null);
}

/// Indica si la prueba sigue activa. Sin fecha configurada se considera activa.
bool trialIsActive(DateTime? expiry, {DateTime? now}) {
  if (expiry == null) return true;
  final current = (now ?? DateTime.now()).toUtc();
  return current.isBefore(expiry.toUtc());
}

/// Días completos que quedan de prueba. Devuelve 0 si ya venció o no hay fecha.
int trialDaysRemaining(DateTime? expiry, {DateTime? now}) {
  if (expiry == null) return 0;
  final difference = expiry.toUtc().difference((now ?? DateTime.now()).toUtc());
  if (difference.isNegative) return 0;
  return difference.inDays;
}

/// Fecha y hora local en un formato compacto y legible.
String formatTrialExpiry(DateTime expiry) {
  return DateFormat('dd/MM/yyyy HH:mm').format(expiry.toLocal());
}

/// Texto humano con el tiempo restante de la prueba.
String trialRemainingLabel(DateTime? expiry, {DateTime? now}) {
  if (expiry == null) return 'Sin fecha límite';

  final difference = expiry.toUtc().difference((now ?? DateTime.now()).toUtc());
  if (difference.isNegative || difference == Duration.zero) return 'Vencida';

  if (difference.inDays >= 1) {
    return difference.inDays == 1
        ? 'Queda 1 día'
        : 'Quedan ${difference.inDays} días';
  }
  if (difference.inHours >= 1) {
    return difference.inHours == 1
        ? 'Queda 1 hora'
        : 'Quedan ${difference.inHours} horas';
  }
  final minutes = difference.inMinutes;
  if (minutes <= 1) return 'Queda menos de 1 minuto';
  return 'Quedan $minutes minutos';
}
