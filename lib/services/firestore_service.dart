import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../app_config.dart';
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
    final data = config.toMap();

    // Las reglas de Firestore no pueden convertir cadenas ISO a fechas, así que
    // se guarda también un Timestamp para poder bloquear la prueba vencida.
    final expiry = DateTime.tryParse(config.trialExpiryDate ?? '');
    if (expiry != null) {
      data['trialExpiryAt'] = Timestamp.fromDate(expiry.toUtc());
    }

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

  /// Un usuario es administrador si existe `admins/{uid}`.
  Future<bool> isAdmin(String uid) async {
    final doc = await _db.collection('admins').doc(uid).get();
    return doc.exists;
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
