import 'package:firebase_auth/firebase_auth.dart';

import '../app_config.dart';
import 'backend_service.dart';

/// Autenticación de clientes y administradores.
///
/// - Admin: correo real + contraseña.
/// - Cliente: usuario + contraseña de 6 dígitos. Internamente se usa el correo
///   sintético `cliente_<usuario>@tarjetfidel.local`.
///
/// El registro se hace por completo en el cliente para funcionar con el plan
/// Spark: se crea la cuenta de Firebase Auth y, en una transacción de
/// Firestore, el perfil y los contadores. Si el perfil no se puede crear, la
/// cuenta de Auth se elimina para no dejar usuarios huérfanos.
class AuthService {
  AuthService({FirebaseAuth? auth, BackendService? backend})
    : _auth = auth ?? FirebaseAuth.instance,
      _backend = backend ?? BackendService();

  final FirebaseAuth _auth;
  final BackendService _backend;

  static final RegExp _usernamePattern = RegExp(
    r'^[a-zA-Z0-9](?:[a-zA-Z0-9._-]{2,31})$',
  );
  static final RegExp _passwordPattern = RegExp(r'^\d{6}$');

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Correo sintético usado internamente para los clientes.
  static String internalEmailFor(String username) {
    return 'cliente_${username.trim().toLowerCase()}@${AppConfig.clientEmailDomain}';
  }

  static String normalizeUsername(String username) =>
      username.trim().toLowerCase();

  static String? validateUsername(String? value) {
    final username = (value ?? '').trim();
    if (username.isEmpty) return 'Escribe un nombre de usuario.';
    if (username.length < 3) return 'Debe tener al menos 3 caracteres.';
    if (username.length > 32) return 'No puede superar los 32 caracteres.';
    if (!_usernamePattern.hasMatch(username)) {
      return 'Usa solo letras, números, punto, guion o guion bajo.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Escribe tu contraseña.';
    if (!_passwordPattern.hasMatch(password)) {
      return 'La contraseña debe tener exactamente 6 dígitos.';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Escribe tu correo.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Escribe un correo válido.';
    }
    return null;
  }

  /// Registra un cliente y deja la sesión iniciada.
  Future<void> registerClient({
    required String username,
    required String password,
    required String displayName,
  }) async {
    final usernameError = validateUsername(username);
    if (usernameError != null) throw AppFailure(usernameError);
    final passwordError = validatePassword(password);
    if (passwordError != null) throw AppFailure(passwordError);
    if (displayName.trim().isEmpty) {
      throw AppFailure('Escribe tu nombre para mostrar.');
    }
    if (displayName.trim().length > 60) {
      throw AppFailure('El nombre no puede superar los 60 caracteres.');
    }

    final normalized = normalizeUsername(username);
    final email = internalEmailFor(normalized);

    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AppFailure(_authMessage(error));
    }

    final user = credential.user;
    if (user == null) {
      throw AppFailure('No se pudo crear la cuenta. Inténtalo de nuevo.');
    }

    try {
      await _backend.registerClientProfile(
        uid: user.uid,
        username: normalized,
        displayName: displayName.trim(),
      );
    } catch (error) {
      // Revierte la cuenta de Auth si el perfil no se pudo crear.
      try {
        await user.delete();
      } catch (_) {
        // Si no se puede borrar, al menos se cierra la sesión.
      }
      await _auth.signOut();
      rethrow;
    }
  }

  Future<void> signInClient({
    required String username,
    required String password,
  }) async {
    final usernameError = validateUsername(username);
    if (usernameError != null) throw AppFailure(usernameError);
    final passwordError = validatePassword(password);
    if (passwordError != null) throw AppFailure(passwordError);

    try {
      await _auth.signInWithEmailAndPassword(
        email: internalEmailFor(username),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AppFailure(_authMessage(error));
    }
  }

  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AppFailure(_authMessage(error));
    }
  }

  /// Envía un enlace para restablecer la contraseña del administrador.
  ///
  /// No revela si el correo existe: la interfaz muestra el mismo mensaje tanto
  /// si la cuenta existe como si no, para evitar enumerar usuarios.
  Future<void> sendAdminPasswordReset({required String email}) async {
    final emailError = validateEmail(email);
    if (emailError != null) throw AppFailure(emailError);

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') return;
      throw AppFailure(_authMessage(error));
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Ese nombre de usuario ya está en uso. Prueba con otro.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Usuario o contraseña incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu red e inténtalo de nuevo.';
      case 'operation-not-allowed':
        return 'El inicio de sesión con correo no está habilitado en Firebase.';
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
    }
    return 'No se pudo iniciar sesión. Inténtalo de nuevo.';
  }
}
