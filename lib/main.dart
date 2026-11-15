import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_config.dart';
import 'firebase_options.dart';
import 'models/config_model.dart';
import 'screens/auth_gate.dart';
import 'services/firestore_service.dart';
import 'theme.dart';
import 'widgets/app_animations.dart';
import 'widgets/config_meta_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!_firebaseIsConfigured()) {
    runApp(const SetupRequiredApp());
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initAppCheck();

  runApp(const TarjetFidelApp());
}

/// Detecta si `firebase_options.dart` ya tiene credenciales reales.
///
/// No se apoya en miembros propios de la plantilla porque
/// `flutterfire configure` sobrescribe ese archivo con el formato oficial.
bool _firebaseIsConfigured() {
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    final apiKey = options.apiKey.trim();
    final projectId = options.projectId.trim();
    return apiKey.isNotEmpty &&
        apiKey != 'REPLACE_ME' &&
        projectId.isNotEmpty &&
        projectId != 'REPLACE_ME';
  } catch (_) {
    return false;
  }
}

/// Activa App Check solo si se compiló con una site key de reCAPTCHA v3.
Future<void> _initAppCheck() async {
  try {
    if (kIsWeb && AppConfig.recaptchaSiteKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(AppConfig.recaptchaSiteKey),
      );
    }
  } catch (error) {
    debugPrint('No se pudo activar App Check: $error');
  }
}

class TarjetFidelApp extends StatefulWidget {
  const TarjetFidelApp({super.key});

  @override
  State<TarjetFidelApp> createState() => _TarjetFidelAppState();
}

class _TarjetFidelAppState extends State<TarjetFidelApp> {
  final FirestoreService _firestore = FirestoreService();
  late final Stream<ConfigModel> _configStream = _firestore.configStream();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConfigModel>(
      stream: _configStream,
      builder: (context, snapshot) {
        final config = snapshot.data ?? ConfigModel.defaults();
        return MaterialApp(
          title: config.businessName,
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(seed: config.color),
          home: ConfigMetaSync(child: const AuthGate()),
        );
      },
    );
  }
}

/// Se muestra cuando `lib/firebase_options.dart` sigue siendo la plantilla.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tarjet Fidel · Configuración',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        body: BrandBackground(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Reveal(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 40,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF4F46E5,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.settings_suggest_rounded,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Configura Firebase para empezar',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Faltan las credenciales del negocio. Créalas con el '
                          'asistente incluido (no se suben a GitHub):',
                          style: TextStyle(height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        const _CodeBlock(
                          'node tool/configure_firebase.mjs\n'
                          'flutter build web --release --no-wasm-dry-run '
                          '--dart-define-from-file=firebase.web.json',
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Después, en la consola de Firebase:',
                          style: TextStyle(height: 1.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Authentication → habilita Correo/contraseña.\n'
                          '• Firestore Database → crea la base de datos y despliega las reglas.\n'
                          '• Remote Config → añade trial_expiry_date (ISO 8601).\n'
                          '• Hosting → publica la carpeta build/web.\n'
                          'Todo funciona con el plan gratuito Spark, sin facturación.',
                          style: TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Las instrucciones completas están en el README.md.',
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(
          color: Color(0xFFE2E8F0),
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}
