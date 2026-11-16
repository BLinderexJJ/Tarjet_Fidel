import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../app_config.dart';
import '../models/admin_role.dart';
import '../models/config_model.dart';
import '../models/stamp_request_model.dart';
import '../models/user_model.dart';

/// Acceso a Firestore. Las operaciones sensibles (solicitudes, aprobaciones,
/// canjes) viven en `BackendService`; aquí solo hay lecturas en tiempo real y
/// la edición de la configuración.
class FirestoreService {
  FirestoreService({FirebaseFirestore? db})
    : _db =
          db ??
          FirebaseFirestore.instanceFor(
            app: Firebase.app(),
            databaseId: AppConfig.firestoreDatabaseId,
          );

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _db.collection('config').doc('main');

  // ---------------------------------------------------------------------------
  // Configuración
  // ---------------------------------------------------------------------------

  Stream<ConfigModel> configStream() {
    return _configRef.snapshots().map(
      (snapshot) => ConfigModel.fromDoc(snapshot.data()),
    );
  }

  Future<ConfigModel> getConfig() async {
    final snapshot = await _configRef.get();
    return ConfigModel.fromDoc(snapshot.data());
  }

  Future<void> saveConfig(ConfigModel config) {
    // La fecha de prueba solo la cambia el superadministrador desde la
    // pestaña Plataforma. El administrador del negocio puede guardar el resto
    // de la configuración sin tocar los campos `trial*`.
    final data = config.toMap()
      ..remove('trialExpiryDate')
      ..remove('trialExpiryAt')
      ..remove('trialUpdatedAt')
      ..remove('trialUpdatedBy');

    return _configRef.set(data, SetOptions(merge: true));
  }

  /// Renueva o fija la fecha de expiración de la prueba.
  ///
  /// Las reglas solo permiten esta escritura a un superadministrador.
  Future<void> saveTrialExpiry(DateTime expiry) {
    final utc = expiry.toUtc();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final data = <String, dynamic>{
      'trialExpiryDate': utc.toIso8601String(),
      'trialExpiryAt': Timestamp.fromDate(utc),
      'trialUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (uid != null && uid.isNotEmpty) data['trialUpdatedBy'] = uid;

    return _configRef.set(data, SetOptions(merge: true));
  }

  /// Quita la fecha límite de la prueba. Solo un superadministrador puede.
  Future<void> clearTrialExpiry() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final data = <String, dynamic>{
      'trialExpiryDate': FieldValue.delete(),
      'trialExpiryAt': FieldValue.delete(),
      'trialUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (uid != null && uid.isNotEmpty) data['trialUpdatedBy'] = uid;

    return _configRef.set(data, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Usuarios y roles
  // ---------------------------------------------------------------------------

  Stream<UserModel?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromDoc(doc);
    });
  }

  Future<UserModel> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw StateError('No existe el documento del usuario $uid');
    }
    return UserModel.fromDoc(doc);
  }

  /// Rol de una cuenta administrativa según `admins/{uid}`.
  ///
  /// Un documento sin `role` se considera administrador del negocio para
  /// mantener compatibilidad con instalaciones anteriores.
  Future<AdminRole> adminRole(String uid) async {
    final doc = await _db.collection('admins').doc(uid).get();
    if (!doc.exists) return AdminRole.none;
    return AdminRole.fromAdminValue(doc.data()?['role']);
  }

  /// Un usuario es administrador (del negocio o de la plataforma) si existe
  /// `admins/{uid}`.
  Future<bool> isAdmin(String uid) async {
    final role = await adminRole(uid);
    return role.isAdmin;
  }

  Stream<List<UserModel>> clientsStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: UserRole.client.name)
        .orderBy('username')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(UserModel.fromDoc).toList());
  }

  // ---------------------------------------------------------------------------
  // Solicitudes de sello
  // ---------------------------------------------------------------------------

  /// Solicitudes pendientes, de la más antigua a la más reciente.
  Stream<List<StampRequestModel>> pendingRequestsStream() {
    return _db
        .collection('stamp_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(StampRequestModel.fromDoc).toList(),
        );
  }

  /// Últimas solicitudes de un cliente.
  Stream<List<StampRequestModel>> myRequestsStream(
    String uid, {
    int limit = 15,
  }) {
    return _db
        .collection('stamp_requests')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(StampRequestModel.fromDoc).toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Historial
  // ---------------------------------------------------------------------------

  Stream<List<VisitModel>> recentVisitsStream(String uid, {int limit = 15}) {
    return _db
        .collection('visits')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(VisitModel.fromDoc).toList());
  }
}
