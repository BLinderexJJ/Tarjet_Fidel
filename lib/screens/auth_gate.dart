import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/config_model.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/firestore_service.dart';
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

  StreamSubscription<User?>? _subscription;
  User? _user;
  bool _initialized = false;
  bool _loading = true;
  bool _isAdmin = false;
  TrialStatus _trial = TrialStatus.activeNow;
  int _resolveToken = 0;

  @override
  void initState() {
    super.initState();
    _subscription = _auth.authStateChanges().listen(_handleUser);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handleUser(User? user) async {
    final token = ++_resolveToken;
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _initialized = true;
        _loading = false;
        _user = null;
        _isAdmin = false;
        _trial = TrialStatus.activeNow;
      });
      return;
    }

    setState(() {
      _initialized = true;
      _loading = true;
      _user = user;
    });

    var isAdmin = false;
    var trial = TrialStatus.activeNow;

    try {
      isAdmin = await _firestore.isAdmin(user.uid);
    } catch (_) {
      // Si falla la lectura del rol, se trata como cliente. El panel admin
      // volverá a validar el rol en el servidor.
    }

    try {
      trial = await _backend.checkTrialStatus();
    } catch (_) {
      // Sin conexión con el servidor no se bloquea la app.
    }

    if (!mounted || token != _resolveToken) return;

    setState(() {
      _isAdmin = isAdmin;
      _trial = trial;
      _loading = false;
    });
  }

  Future<void> _signOut() => _auth.signOut();

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _loading) {
      return StreamBuilder<ConfigModel>(
        stream: _configStream,
        builder: (context, snapshot) {
          final config = snapshot.data ?? ConfigModel.defaults();
          return SplashScreen(
            businessName: config.businessName,
            color: config.color,
          );
        },
      );
    }

    final user = _user;
    if (user == null) return const AuthScreen();

    if (!_trial.active) {
      return TrialBlockedScreen(trial: _trial, onSignOut: _signOut);
    }

    if (_isAdmin) {
      return AdminScreen(user: user);
    }

    return ClientScreen(user: user);
  }
}
