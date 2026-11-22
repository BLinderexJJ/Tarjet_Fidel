import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../app_config.dart';
import '../models/admin_account.dart';
import 'backend_service.dart';

/// Alta de administradores de negocio hecha por el superadministrador.
///
/// No hay Cloud Functions (plan Spark): la cuenta de Auth se crea con una app
/// secundaria de Firebase para no cerrar la sesión del superadministrador, y
/// el documento `admins/{uid}` se escribe con su sesión privilegiada. Las
/// reglas de Firestore impiden que un administrador del negocio haga esto.
class AdminManagementService {
  AdminManagementService({FirebaseFirestore? db})
    : _db =
          db ??
          FirebaseFirestore.instanceFor(
            app: Firebase.app(),
            databaseId: AppConfig.firestoreDatabaseId,
          );

  final FirebaseFirestore _db;

  /// Administradores existentes, para mostrarlos en el panel.
  Stream<List<AdminAccount>> adminStream() {
    return _db
        .collection('admins')
        .orderBy('email')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AdminAccount.fromDoc).toList(growable: false),
        );
  }

  /// Crea una cuenta de Firebase Auth y su documento `admins/{uid}` con rol
  /// de administrador del negocio. Devuelve el UID creado.
  Future<String> createBusinessAdmin({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = displayName.trim();
    final secondaryName =
        'admin_creation_${DateTime.now().microsecondsSinceEpoch}';

    FirebaseApp? secondaryApp;
    User? createdUser;

    try {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryName,
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      createdUser = credential.user;
      if (createdUser == null) {
        throw AppFailure('No se pudo crear la cuenta de Auth.');
      }

      await _writeAdminDoc(createdUser.uid, normalizedEmail, normalizedName);
      return createdUser.uid;
    } on FirebaseAuthException catch (error) {
      throw _translate(error);
    } catch (error) {
      // Si falla el documento, se elimina la cuenta recién creada para no
      // dejar usuarios huérfanos sin rol.
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {
          // Se intentó; si no se puede, las reglas dejan la cuenta inofensiva.
        }
      }
      if (error is AppFailure) rethrow;
      throw AppFailure(
        'No se pudo crear el administrador. Inténtalo de nuevo.',
      );
    } finally {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {
          // La app secundaria es temporal; no afecta a la sesión principal.
        }
      }
    }
  }

  Future<void> _writeAdminDoc(String uid, String email, String displayName) {
    return _db.collection('admins').doc(uid).set(<String, dynamic>{
      'email': email,
      'displayName': displayName,
      'role': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  AppFailure _translate(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return AppFailure(
          'Ya existe una cuenta con ese correo.',
          code: error.code,
        );
      case 'invalid-email':
        return AppFailure('El correo no es válido.', code: error.code);
      case 'weak-password':
        return AppFailure(
          'La contraseña es demasiado débil.',
          code: error.code,
        );
      case 'operation-not-allowed':
        return AppFailure(
          'El acceso con correo y contraseña no está habilitado en Firebase.',
          code: error.code,
        );
      case 'network-request-failed':
        return AppFailure(
          'No hay conexión con Firebase. Inténtalo de nuevo.',
          code: error.code,
        );
      default:
        return AppFailure(
          'No se pudo crear la cuenta: ${error.message ?? error.code}',
          code: error.code,
        );
    }
  }
}
