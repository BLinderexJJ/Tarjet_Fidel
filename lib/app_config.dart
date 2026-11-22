/// Constantes de configuración de la aplicación.
class AppConfig {
  const AppConfig._();

  /// ID de la base de datos de Firestore.
  ///
  /// Firebase crea por defecto la base `(default)`, pero crearla por API exige
  /// el plan Blaze. La base con nombre `default` (sin paréntesis) sí se puede
  /// crear en el plan Spark, por lo que el proyecto la usa a propósito.
  ///
  /// Se inyecta al compilar para que cada negocio pueda usar otra base:
  /// `--dart-define=FIRESTORE_DATABASE_ID=default` o, mejor, desde
  /// `firebase.web.json` con `--dart-define-from-file=firebase.web.json`.
  /// Debe coincidir con `firestore.database` de `firebase.json`.
  static const String firestoreDatabaseId = String.fromEnvironment(
    'FIRESTORE_DATABASE_ID',
    defaultValue: 'default',
  );

  /// Site key de reCAPTCHA v3 para App Check.
  ///
  /// Se inyecta al compilar:
  /// `flutter build web --dart-define=RECAPTCHA_SITE_KEY=tu_site_key`
  static const String recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_SITE_KEY',
  );

  /// Dominio del correo sintético de los clientes.
  static const String clientEmailDomain = 'tarjetfidel.local';

  /// Prefijo del payload de los QR de check-in.
  static const String qrPrefix = 'TARJET:';

  /// Tamaño máximo del archivo de logo que se puede seleccionar.
  static const int maxLogoInputBytes = 8 * 1024 * 1024; // 8 MB
  static const int maxLogoInputMb = 8;

  /// Tamaño máximo de la imagen ya codificada en base64.
  ///
  /// Firestore limita cada documento a 1 MiB y `config/main` guarda más datos,
  /// así que el logo se mantiene muy por debajo de ese límite.
  static const int maxLogoDataUriBytes = 600 * 1024; // 600 KB

  /// Tamaño máximo del archivo de imagen del sello que se puede seleccionar.
  static const int maxStampImageInputBytes = 8 * 1024 * 1024; // 8 MB
  static const int maxStampImageInputMb = 8;

  /// La imagen del sello se muestra a unos 50 px, así que basta con reducirla
  /// a 192 px. El límite bajo deja margen en `config/main` para guardar también
  /// el logo dentro del tope de 1 MiB por documento de Firestore.
  static const int maxStampImageDataUriBytes = 160 * 1024; // 160 KB
  static const int stampImageResizeWidth = 192;

  /// Presupuesto máximo combinado de logo + sello ya codificados en base64.
  /// 900 KB deja margen seguro bajo el límite de 1 MiB de Firestore.
  static const int maxConfigImageDataLength = 900 * 1024;
}
