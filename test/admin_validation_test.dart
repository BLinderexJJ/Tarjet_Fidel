import 'package:flutter_test/flutter_test.dart';
import 'package:tarjet_fidel/utils/admin_validation.dart';

void main() {
  group('validateAdminEmail', () {
    test('acepta un correo real y lo recorta', () {
      expect(validateAdminEmail('  ADMIN@ejemplo.com  '), isNull);
    });

    test('rechaza correos vacíos, inválidos y sintéticos', () {
      expect(validateAdminEmail(''), isNotNull);
      expect(validateAdminEmail('sin-arroba'), isNotNull);
      expect(
        validateAdminEmail('admin@tarjetfidel.local'),
        contains('correo real'),
      );
    });
  });

  group('validateAdminDisplayName', () {
    test('acepta nombres razonables', () {
      expect(validateAdminDisplayName('María'), isNull);
      expect(validateAdminDisplayName('  Juan Pérez  '), isNull);
    });

    test('rechaza nombres vacíos o demasiado largos', () {
      expect(validateAdminDisplayName(''), isNotNull);
      expect(validateAdminDisplayName('A'), isNotNull);
      expect(validateAdminDisplayName('x' * 61), isNotNull);
    });
  });

  group('validateAdminPassword', () {
    test('acepta una contraseña con letras y números', () {
      expect(validateAdminPassword('ClaveSegura123'), isNull);
    });

    test('rechaza contraseñas cortas o sin letras/números', () {
      expect(validateAdminPassword(''), isNotNull);
      expect(validateAdminPassword('Ab1'), isNotNull);
      expect(validateAdminPassword('solo-letras'), isNotNull);
      expect(validateAdminPassword('12345678'), isNotNull);
    });
  });
}
