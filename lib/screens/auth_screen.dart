import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/config_model.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../utils/motion.dart';
import '../widgets/app_animations.dart';
import '../widgets/logo_image.dart';

/// Pantalla de acceso para clientes y administradores.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();
  late final Stream<ConfigModel> _configStream = _firestore.configStream();

  final _clientFormKey = GlobalKey<FormState>();
  final _adminFormKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  int _mode = 0; // 0 = cliente, 1 = administrador
  bool _registerMode = false;
  bool _loading = false;
  bool _resetLoading = false;
  bool _obscureClientPassword = true;
  bool _obscureAdminPassword = true;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  void _setMode(int mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  Future<void> _submitClient() async {
    if (_loading) return;
    if (!(_clientFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_registerMode) {
        await _auth.registerClient(
          username: _usernameController.text,
          password: _passwordController.text,
          displayName: _displayNameController.text,
        );
      } else {
        await _auth.signInClient(
          username: _usernameController.text,
          password: _passwordController.text,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppFailure
            ? error.message
            : 'No se pudo completar la operación. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAdmin() async {
    if (_loading) return;
    if (!(_adminFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _auth.signInAdmin(
        email: _adminEmailController.text,
        password: _adminPasswordController.text,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppFailure
            ? error.message
            : 'No se pudo iniciar sesión. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendAdminReset() async {
    if (_loading || _resetLoading) return;
    final emailError = AuthService.validateEmail(_adminEmailController.text);
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }

    setState(() {
      _resetLoading = true;
      _error = null;
    });

    try {
      await _auth.sendAdminPasswordReset(email: _adminEmailController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Si el correo está registrado, recibirás un enlace para '
              'restablecer la contraseña.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppFailure
            ? error.message
            : 'No se pudo enviar el enlace. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _resetLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<ConfigModel>(
        stream: _configStream,
        builder: (context, snapshot) {
          final config = snapshot.data ?? ConfigModel.defaults();
          return BrandBackground(
            color: config.color,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Reveal(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 40,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(config: config),
                          const SizedBox(height: 24),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(
                                value: 0,
                                icon: Icon(Icons.person_rounded),
                                label: Text('Cliente'),
                              ),
                              ButtonSegment(
                                value: 1,
                                icon: Icon(Icons.admin_panel_settings_rounded),
                                label: Text('Administrador'),
                              ),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (selection) =>
                                _setMode(selection.first),
                          ),
                          const SizedBox(height: 22),
                          AnimatedSize(
                            duration: prefersReducedMotion(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            child: AnimatedSwitcher(
                              duration: prefersReducedMotion(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.04),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: KeyedSubtree(
                                key: ValueKey(_mode),
                                child: _mode == 0
                                    ? _buildClientForm()
                                    : _buildAdminForm(),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Reveal(
                              slide: 0.03,
                              child: _ErrorBox(message: _error!),
                            ),
                          ],
                          if (config.contactInfo.trim().isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              '¿Necesitas ayuda? ${config.contactInfo}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.black54),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClientForm() {
    return Form(
      key: _clientFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_registerMode) ...[
            TextFormField(
              controller: _displayNameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Tu nombre',
                hintText: 'Ej: Ana García',
                prefixIcon: Icon(Icons.badge_rounded),
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Escribe tu nombre.' : null,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Usuario',
              hintText: 'Ej: ana.garcia',
              prefixIcon: Icon(Icons.alternate_email_rounded),
              border: OutlineInputBorder(),
            ),
            validator: AuthService.validateUsername,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscureClientPassword,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitClient(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'Contraseña (6 dígitos)',
              prefixIcon: const Icon(Icons.pin_rounded),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscureClientPassword ? 'Mostrar' : 'Ocultar',
                onPressed: () => setState(
                  () => _obscureClientPassword = !_obscureClientPassword,
                ),
                icon: Icon(
                  _obscureClientPassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
            ),
            validator: AuthService.validatePassword,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _submitClient,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_registerMode ? 'Crear cuenta' : 'Entrar'),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                    _registerMode = !_registerMode;
                    _error = null;
                  }),
            child: Text(
              _registerMode
                  ? '¿Ya tienes cuenta? Inicia sesión'
                  : '¿No tienes cuenta? Regístrate',
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Si olvidaste tu contraseña, pide al negocio que te ayude a '
            'recuperarla.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black45, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminForm() {
    return Form(
      key: _adminFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _adminEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Correo del administrador',
              hintText: 'admin@negocio.com',
              prefixIcon: Icon(Icons.mail_rounded),
              border: OutlineInputBorder(),
            ),
            validator: AuthService.validateEmail,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _adminPasswordController,
            obscureText: _obscureAdminPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitAdmin(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_rounded),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscureAdminPassword ? 'Mostrar' : 'Ocultar',
                onPressed: () => setState(
                  () => _obscureAdminPassword = !_obscureAdminPassword,
                ),
                icon: Icon(
                  _obscureAdminPassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
            ),
            validator: (value) =>
                (value ?? '').isEmpty ? 'Escribe tu contraseña.' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _submitAdmin,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Entrar al panel'),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading || _resetLoading ? null : _sendAdminReset,
              child: _resetLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.config});

  final ConfigModel config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Pulse(
          maxScale: 1.045,
          duration: const Duration(milliseconds: 1800),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: LogoImage(
              source: config.logoUrl,
              fallback: Icon(
                Icons.storefront_rounded,
                size: 34,
                color: config.color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          config.businessName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Accede a tu tarjeta de fidelidad',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5B5B5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: Color(0xFFB3261E),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB3261E), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
