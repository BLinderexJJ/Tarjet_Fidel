import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarjet_fidel/models/config_model.dart';
import 'package:tarjet_fidel/models/user_model.dart';
import 'package:tarjet_fidel/utils/codes.dart';

void main() {
  group('ConfigModel', () {
    test('usa valores por defecto con un mapa vacío', () {
      final config = ConfigModel.fromMap(const {});

      expect(config.businessName, ConfigModel.defaultBusinessName);
      expect(config.stampsGoal, ConfigModel.defaultStampsGoal);
      expect(config.maxUsers, ConfigModel.defaultMaxUsers);
      expect(config.checkinCode, isEmpty);
    });

    test('interpreta color, payload y mapa', () {
      final config = ConfigModel.fromMap(const {
        'businessName': 'Café Sol',
        'themeColor': '#10B981',
        'stampsGoal': 8,
        'checkinCode': 'AB12CD',
        'maxUsers': 120,
      });

      expect(config.businessName, 'Café Sol');
      expect(config.color.toARGB32(), 0xFF10B981);
      expect(config.stampsGoal, 8);
      expect(config.checkinPayload, 'TARJET:AB12CD');
      expect(config.toMap()['maxUsers'], 120);
    });

    test('no lanza con un color inválido', () {
      final config = ConfigModel.fromMap(const {'themeColor': 'no-es-color'});
      expect(config.color, const Color(0xFF4F46E5));
    });
  });

  group('UserModel', () {
    test('parsea un cliente', () {
      final user = UserModel.fromMap('uid-1', const {
        'username': 'ana',
        'displayName': 'Ana García',
        'currentStamps': 4,
        'totalVisits': 7,
        'role': 'client',
        'isRewardReady': true,
      });

      expect(user.uid, 'uid-1');
      expect(user.name, 'Ana García');
      expect(user.isClient, isTrue);
      expect(user.isAdmin, isFalse);
      expect(user.currentStamps, 4);
      expect(user.totalVisits, 7);
      expect(user.isRewardReady, isTrue);
    });

    test('usa el username si no hay nombre visible', () {
      final user = UserModel.fromMap('uid-2', const {
        'username': 'pedro',
        'role': 'client',
      });

      expect(user.name, 'pedro');
      expect(user.currentStamps, 0);
    });

    test('calcula el premio listo con la meta actual', () {
      final user = UserModel.fromMap('uid-3', const {
        'username': 'lucia',
        'currentStamps': 6,
        'isRewardReady': false,
      });

      expect(user.isRewardReadyFor(5), isTrue);
      expect(user.isRewardReadyFor(6), isTrue);
      expect(user.isRewardReadyFor(10), isFalse);
      expect(user.isRewardReadyFor(0), isTrue);
    });
  });

  group('normalizeCheckinCode', () {
    test('quita el prefijo del payload', () {
      expect(normalizeCheckinCode('TARJET:ab12cd'), 'AB12CD');
    });

    test('lee el parámetro code de una URL', () {
      expect(
        normalizeCheckinCode('https://negocio.com/checkin?code=xy99zz'),
        'XY99ZZ',
      );
    });

    test('acepta el código directo y recorta espacios', () {
      expect(normalizeCheckinCode('  ab12cd  '), 'AB12CD');
    });

    test('devuelve vacío con una cadena vacía', () {
      expect(normalizeCheckinCode('   '), isEmpty);
    });
  });

  test('generateCheckinCode genera códigos de 6 caracteres', () {
    final code = generateCheckinCode();
    expect(code, hasLength(6));
    expect(RegExp(r'^[A-Z2-9]+$').hasMatch(code), isTrue);
  });
}
