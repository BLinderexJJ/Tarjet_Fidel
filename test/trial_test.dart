import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarjet_fidel/utils/trial.dart';

void main() {
  group('parseTrialExpiry', () {
    test('devuelve null para valores vacíos o inválidos', () {
      expect(parseTrialExpiry(null), isNull);
      expect(parseTrialExpiry('   '), isNull);
      expect(parseTrialExpiry('no-es-fecha'), isNull);
    });

    test('normaliza la fecha a UTC', () {
      final expiry = parseTrialExpiry('2026-11-27T23:59:59Z');

      expect(expiry, isNotNull);
      expect(expiry!.isUtc, isTrue);
      expect(expiry, DateTime.utc(2026, 11, 27, 23, 59, 59));
    });
  });

  group('trialExpiryFromMap', () {
    test('prefiere el Timestamp de Firestore', () {
      final expiry = trialExpiryFromMap({
        'trialExpiryAt': Timestamp.fromDate(DateTime.utc(2026, 12, 1)),
        'trialExpiryDate': '2026-01-01T00:00:00Z',
      });

      expect(expiry, DateTime.utc(2026, 12, 1));
    });

    test('cae en la cadena ISO cuando no hay Timestamp', () {
      final expiry = trialExpiryFromMap({
        'trialExpiryDate': '2026-11-27T23:59:59Z',
      });

      expect(expiry, DateTime.utc(2026, 11, 27, 23, 59, 59));
    });

    test('devuelve null sin fecha configurada', () {
      expect(trialExpiryFromMap(const {}), isNull);
    });
  });

  group('trialIsActive', () {
    final now = DateTime.utc(2026, 11, 16, 12);

    test('sin fecha se considera activa', () {
      expect(trialIsActive(null, now: now), isTrue);
    });

    test('una fecha futura está activa', () {
      expect(trialIsActive(DateTime.utc(2026, 11, 17), now: now), isTrue);
    });

    test('una fecha pasada está vencida', () {
      expect(trialIsActive(DateTime.utc(2026, 11, 15), now: now), isFalse);
    });
  });

  group('trialDaysRemaining', () {
    final now = DateTime.utc(2026, 11, 16, 12);

    test('cuenta días completos restantes', () {
      expect(trialDaysRemaining(DateTime.utc(2026, 11, 21, 12), now: now), 5);
    });

    test('nunca devuelve negativos', () {
      expect(trialDaysRemaining(DateTime.utc(2026, 11, 10), now: now), 0);
    });
  });

  group('formatTrialExpiry', () {
    test('muestra fecha y hora locales', () {
      final local = DateTime(2026, 11, 27, 23, 59);

      expect(formatTrialExpiry(local), '27/11/2026 23:59');
    });
  });

  group('trialRemainingLabel', () {
    final now = DateTime.utc(2026, 11, 16, 12);

    test('sin fecha no muestra límite', () {
      expect(trialRemainingLabel(null, now: now), 'Sin fecha límite');
    });

    test('con fecha pasada indica vencida', () {
      expect(
        trialRemainingLabel(DateTime.utc(2026, 11, 15), now: now),
        'Vencida',
      );
    });

    test('usa singular y plural en días', () {
      expect(
        trialRemainingLabel(DateTime.utc(2026, 11, 17, 12), now: now),
        'Queda 1 día',
      );
      expect(
        trialRemainingLabel(DateTime.utc(2026, 11, 21, 12), now: now),
        'Quedan 5 días',
      );
    });

    test('usa horas y minutos cuando falta menos de un día', () {
      expect(
        trialRemainingLabel(DateTime.utc(2026, 11, 16, 14, 12), now: now),
        'Quedan 2 horas',
      );
      expect(
        trialRemainingLabel(DateTime.utc(2026, 11, 16, 12, 30), now: now),
        'Quedan 30 minutos',
      );
      expect(
        trialRemainingLabel(DateTime.utc(2026, 11, 16, 12, 0, 30), now: now),
        'Queda menos de 1 minuto',
      );
    });
  });
}
