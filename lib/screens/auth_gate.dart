import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/admin_role.dart';
import '../models/config_model.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/firestore_service.dart';
import '../utils/trial.dart';
import 'admin_screen.dart';
import 'auth_screen.dart';
import 'client_screen.dart';
import 'splash_screen.dart';
import 'trial_blocked_screen.dart';

/// Decide qué pantalla mostrar según la sesión, el rol y el estado de prueba.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();
  final BackendService _backend = BackendService();

  late final Stream<ConfigModel> _configStream = _firestore.configStream();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<ConfigModel>? _configSubscription;
  Timer? _trialTimer;

  User? _user;
  ConfigModel? _config;
  bool _initialized = false;
  bool _loading = true;
  AdminRole _role = AdminRole.none;
  TrialStatus _trial = TrialStatus.activeNow;
  int _resolveToken = 0;

  @override
  void initState() {
    super.initState();
    _authSubscription = _auth.authStateChanges().listen(_handleUser);
    _configSubscription = _configStream.listen(_handleConfig, onError: (_) {});
  }

  @override
  void dispose() {
    _trialTimer?.cancel();
    _authSubscription?.cancel();
    _configSubscription?.cancel();
    super.dispose();
  }

  /// Mantiene el estado de la prueba sincronizado con `config/main`.
  ///
  /// Así, cuando el superadministrador renueva la prueba, los clientes y el
  /// panel del negocio se desbloquean sin recargar la página.
  void _handleConfig(ConfigModel config) {
    if (!mounted) return;
    final loggedIn = _user != null;
    setState(() {
      _config = config;
      if (loggedIn) _trial = _statusFor(config.trialExpiry);
    });
    if (loggedIn) _scheduleTrialTimer(config.trialExpiry);
  }

  Future<void> _handleUser(User? user) async {
    final token = ++_resolveToken;
    if (!mounted) return;

    if (user == null) {
      _trialTimer?.cancel();
      setState(() {
        _initialized = true;
        _loading = false;
        _user = null;
        _role = AdminRole.none;
        _trial = TrialStatus.activeNow;
      });
      return;
    }

    setState(() {
      _initialized = true;
      _loading = true;
      _user = user;
    });

    var role = AdminRole.none;
    var trial = _statusFor(_config?.trialExpiry);

    try {
      role = await _firestore.adminRole(user.uid);
    } catch (_) {
      // Si falla la lectura del rol, se trata como cliente. El panel admin
      // volverá a validar el rol en el servidor.
    }

    // Si la configuración en tiempo real aún no trae una fecha, se consulta
    // Firestore y, como respaldo, Remote Config.
    if (_config?.trialExpiry == null) {
      try {
        trial = await _backend.checkTrialStatus();
      } catch (_) {
        // Sin conexión con el servidor no se bloquea la app.
      }
    }

    if (!mounted || token != _resolveToken) return;

    setState(() {
      _role = role;
      _trial = trial;
      _loading = false;
    });
    _scheduleTrialTimer(trial.expiryDate);
  }

  TrialStatus _statusFor(DateTime? expiry) {
    return TrialStatus(
      active: trialIsActive(expiry),
      expiryDate: expiry,
      daysRemaining: trialDaysRemaining(expiry),
    );
  }

  /// Programa un aviso exacto para el momento en que vence la prueba.
  void _scheduleTrialTimer(DateTime? expiry) {
    _trialTimer?.cancel();
    _trialTimer = null;
    if (expiry == null) return;

    final remaining = expiry.toUtc().difference(DateTime.now().toUtc());
    if (remaining.isNegative || remaining == Duration.zero) return;

    _trialTimer = Timer(remaining, () {
      if (!mounted) return;
      setState(() => _trial = _statusFor(expiry));
    });
  }

  Future<void> _signOut() => _auth.signOut();

  @override
  Widget build(BuildContext context) {
    final config = _config ?? ConfigModel.defaults();

    if (!_initialized || _loading) {
      return SplashScreen(
        businessName: config.businessName,
        color: config.color,
      );
    }

    final user = _user;
    if (user == null) return const AuthScreen();

    // El superadministrador debe poder entrar aunque la prueba esté vencida:
    // su panel es el que permite renovarla.
    if (_role == AdminRole.superadmin) {
      return AdminScreen(user: user, role: _role);
    }

    if (!_trial.active) {
      return TrialBlockedScreen(trial: _trial, onSignOut: _signOut);
    }

    if (_role == AdminRole.admin) {
      return AdminScreen(user: user, role: _role);
    }

    return ClientScreen(user: user);
  }
}
