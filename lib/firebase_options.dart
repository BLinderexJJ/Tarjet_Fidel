import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuración de Firebase **por negocio**.
///
/// Este archivo no contiene credenciales. Se inyectan al compilar desde un
/// JSON local que no se sube a GitHub:
///
/// ```bash
/// flutter run -d chrome --dart-define-from-file=firebase.web.json
/// flutter build web --release --dart-define-from-file=firebase.web.json
/// ```
///
/// Crea `firebase.web.json` con `node tool/configure_firebase.mjs` o copiando
/// `firebase.web.example.json`. Si falta, la app muestra una pantalla de
/// configuración en lugar de fallar.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const String apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'REPLACE_ME',
  );
  static const String appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: 'REPLACE_ME',
  );
  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: 'REPLACE_ME',
  );
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'REPLACE_ME',
  );
  static const String authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'REPLACE_ME',
  );
  static const String storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'REPLACE_ME',
  );
  static const String measurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
    defaultValue: '',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain,
    storageBucket: storageBucket,
    measurementId: measurementId,
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Tarjet Fidel está pensado para Flutter Web. '
      'Configura las credenciales de la plataforma que necesites.',
    );
  }

  /// `true` cuando se compiló con credenciales reales.
  static bool get isConfigured =>
      apiKey != 'REPLACE_ME' && projectId != 'REPLACE_ME';
}
