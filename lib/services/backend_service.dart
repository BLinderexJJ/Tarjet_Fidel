import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../app_config.dart';
import '../models/config_model.dart';
import '../utils/codes.dart';

/// Error de negocio con un mensaje listo para mostrar al usuario.
class AppFailure implements Exception {
  AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Estado de la prueba del negocio.
class TrialStatus {
  const TrialStatus({
    required this.active,
    this.expiryDate,
    this.daysRemaining,
  });

  final bool active;
  final DateTime? expiryDate;
  final int? daysRemaining;

  factory TrialStatus.fromMap(Map<String, dynamic> data) {
    final rawExpiry = data['expiryDate'] as String?;
    return TrialStatus(
      active: data['active'] as bool? ?? true,
      expiryDate: rawExpiry == null ? null : DateTime.tryParse(rawExpiry),
      daysRemaining: (data['daysRemaining'] as num?)?.toInt(),
    );
  }

  static const TrialStatus activeNow = TrialStatus(active: true);
}

/// Lógica de negocio ejecutada en el cliente con transacciones de Firestore.
///
/// El plan Spark no permite Cloud Functions ni Storage, así que estas
/// operaciones viven en la app y las reglas de `firestore.rules` son las que
/// impiden el fraude: solo se crean solicitudes `pending`, el código debe
/// coincidir con `config/main.checkinCode`, hay como máximo una solicitud
/// pendiente por cliente y un tope de 10 solicitudes cada 24 horas.
class BackendService {
  BackendService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db =
          db ??
          FirebaseFirestore.instanceFor(
            app: Firebase.app(),
            databaseId: AppConfig.firestoreDatabaseId,
          ),
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Máximo de solicitudes por cliente en la ventana indicada.
  static const int rateLimitMax = 10;
  static const Duration rateLimitWindow = Duration(hours: 24);

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _db.collection('config').doc('main');

  DocumentReference<Map<String, dynamic>> get _clientsCounterRef =>
      _db.collection('counters').doc('clients');

  // ---------------------------------------------------------------------------
  // Registro de clientes
  // ---------------------------------------------------------------------------

  /// Crea el perfil del cliente después de registrar su cuenta de Auth.
  ///
  /// Se ejecuta en una transacción que:
  /// - comprueba la prueba del negocio y el máximo de usuarios;
  /// - crea `users/{uid}` y `usernames/{username}`;
  /// - incrementa `counters/clients`.
  Future<void> registerClientProfile({
    required String uid,
    required String username,
    required String displayName,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final usernameRef = _db.collection('usernames').doc(username);
    final counterRef = _clientsCounterRef;

    try {
      await _db.runTransaction((transaction) async {
        final configSnapshot = await transaction.get(_configRef);
        final counterSnapshot = await transaction.get(counterRef);

        final config = ConfigModel.fromDoc(configSnapshot.data());
        final expiry = _parseDate(config.trialExpiryDate);
        if (expiry != null && DateTime.now().toUtc().isAfter(expiry)) {
          throw AppFailure(
            'La prueba del negocio ha expirado. Contacta con el administrador.',
            code: 'trial_expired',
          );
        }

        final count = (counterSnapshot.data()?['count'] as num?)?.toInt() ?? 0;
        if (count >= config.maxUsers) {
          throw AppFailure(
            'El negocio alcanzó su límite de usuarios. Contacta con el administrador.',
            code: 'limit_reached',
          );
        }

        transaction.set(userRef, {
          'username': username,
          'usernameLower': username,
          'internalEmail': _auth.currentUser?.email ?? '',
          'displayName': displayName,
          'currentStamps': 0,
          'totalVisits': 0,
          'role': 'client',
          'isRewardReady': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(usernameRef, {
          'uid': uid,
          'username': username,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(counterRef, {
          'count': count + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  // ---------------------------------------------------------------------------
  // Solicitudes de sello
  // ---------------------------------------------------------------------------

  /// Crea una solicitud `pending`. El QR nunca otorga sellos directamente.
  Future<String> createStampRequest({required String code}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AppFailure(
        'Tu sesión expiró. Vuelve a iniciar sesión.',
        code: 'unauthenticated',
      );
    }

    final normalizedCode = normalizeCheckinCode(code);
    if (normalizedCode.isEmpty) {
      throw AppFailure(
        'El código escaneado no es válido o ya no está activo.',
        code: 'invalid_code',
      );
    }

    final userRef = _db.collection('users').doc(user.uid);
    final pendingRef = _db.collection('pending_requests').doc(user.uid);
    final rateRef = _db.collection('rate_limits').doc(user.uid);
    final requestRef = _db.collection('stamp_requests').doc();

    try {
      await _db.runTransaction((transaction) async {
        final configSnapshot = await transaction.get(_configRef);
        final userSnapshot = await transaction.get(userRef);
        final pendingSnapshot = await transaction.get(pendingRef);
        final rateSnapshot = await transaction.get(rateRef);

        final config = ConfigModel.fromDoc(configSnapshot.data());
        final expectedCode = normalizeCheckinCode(config.checkinCode);
        if (expectedCode.isEmpty || expectedCode != normalizedCode) {
          throw AppFailure(
            'El código escaneado no es válido o ya no está activo.',
            code: 'invalid_code',
          );
        }

        if (!userSnapshot.exists) {
          throw AppFailure(
            'No encontramos tu perfil de cliente. Vuelve a iniciar sesión.',
            code: 'user_not_found',
          );
        }

        final userData = userSnapshot.data() ?? const <String, dynamic>{};
        if (userData['role'] != 'client') {
          throw AppFailure(
            'Esta acción solo está disponible para clientes.',
            code: 'client_only',
          );
        }

        if (pendingSnapshot.exists) {
          throw AppFailure(
            'Ya tienes una solicitud pendiente. Espera la aprobación del administrador.',
            code: 'pending_exists',
          );
        }

        final now = DateTime.now().toUtc();
        final rateData = rateSnapshot.data();
        final storedWindowStart = (rateData?['windowStart'] as Timestamp?)
            ?.toDate()
            .toUtc();
        final windowActive =
            storedWindowStart != null &&
            now.difference(storedWindowStart) < rateLimitWindow;
        final previousCount = windowActive
            ? (rateData?['count'] as num?)?.toInt() ?? 0
            : 0;

        if (previousCount >= rateLimitMax) {
          throw AppFailure(
            'Has enviado demasiadas solicitudes en las últimas 24 horas. Inténtalo más tarde.',
            code: 'rate_limited',
          );
        }

        final displayName = (userData['displayName'] as String?)?.trim() ?? '';
        final username = (userData['username'] as String?)?.trim() ?? '';
        final userName = displayName.isNotEmpty
            ? displayName
            : (username.isNotEmpty ? username : 'Cliente');

        transaction.set(requestRef, {
          'userId': user.uid,
          'userName': userName,
          'status': 'pending',
          'stampsAwarded': 1,
          'code': normalizedCode,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(pendingRef, {
          'requestId': requestRef.id,
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (windowActive) {
          transaction.set(rateRef, {
            'count': previousCount + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          transaction.set(rateRef, {
            'count': 1,
            'windowStart': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });

      return requestRef.id;
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  /// Aprueba una solicitud y suma los sellos de forma atómica.
  Future<void> approveStampRequest({
    required String requestId,
    int stampsAwarded = 1,
  }) async {
    final admin = _requireAdmin();
    final safeStamps = stampsAwarded.clamp(1, 10);

    final requestRef = _db.collection('stamp_requests').doc(requestId);

    try {
      await _db.runTransaction((transaction) async {
        final configSnapshot = await transaction.get(_configRef);
        final requestSnapshot = await transaction.get(requestRef);

        if (!requestSnapshot.exists) {
          throw AppFailure('No se encontró la solicitud.', code: 'not_found');
        }

        final requestData = requestSnapshot.data() ?? const <String, dynamic>{};
        final status = requestData['status'] as String? ?? '';
        if (status == 'approved') {
          throw AppFailure(
            'La solicitud ya había sido aprobada.',
            code: 'already_approved',
          );
        }
        if (status != 'pending') {
          throw AppFailure(
            'La solicitud ya fue procesada por otro administrador.',
            code: 'request_not_pending',
          );
        }

        final userId = (requestData['userId'] as String?) ?? '';
        if (userId.isEmpty) {
          throw AppFailure(
            'No se encontró el usuario de la solicitud.',
            code: 'user_not_found',
          );
        }

        final userRef = _db.collection('users').doc(userId);
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw AppFailure(
            'No se encontró el usuario de la solicitud.',
            code: 'user_not_found',
          );
        }

        final config = ConfigModel.fromDoc(configSnapshot.data());
        final goal = config.stampsGoal.clamp(1, 100);
        final userData = userSnapshot.data() ?? const <String, dynamic>{};
        final currentStamps = (userData['currentStamps'] as num?)?.toInt() ?? 0;
        final totalVisits = (userData['totalVisits'] as num?)?.toInt() ?? 0;
        final newStamps = currentStamps + safeStamps;
        final isRewardReady = newStamps >= goal;

        transaction.update(userRef, {
          'currentStamps': newStamps,
          'totalVisits': totalVisits + 1,
          'isRewardReady': isRewardReady,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(_db.collection('visits').doc(), {
          'userId': userId,
          'stamps': safeStamps,
          'approvedBy': admin.uid,
          'requestId': requestId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        transaction.update(requestRef, {
          'status': 'approved',
          'stampsAwarded': safeStamps,
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': admin.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.delete(_db.collection('pending_requests').doc(userId));
      });
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  /// Rechaza una solicitud pendiente.
  Future<void> rejectStampRequest({required String requestId}) async {
    final admin = _requireAdmin();
    final requestRef = _db.collection('stamp_requests').doc(requestId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(requestRef);

        if (!snapshot.exists) {
          throw AppFailure('No se encontró la solicitud.', code: 'not_found');
        }

        final data = snapshot.data() ?? const <String, dynamic>{};
        if (data['status'] != 'pending') {
          throw AppFailure(
            'La solicitud ya fue procesada por otro administrador.',
            code: 'request_not_pending',
          );
        }

        final userId = (data['userId'] as String?) ?? '';

        transaction.update(requestRef, {
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': admin.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (userId.isNotEmpty) {
          transaction.delete(_db.collection('pending_requests').doc(userId));
        }
      });
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  /// Canjea el premio de un cliente: reinicia sus sellos y deja un registro
  /// inmutable en `redemptions`.
  Future<void> resetStamps({required String userId}) async {
    final admin = _requireAdmin();
    final userRef = _db.collection('users').doc(userId);

    try {
      await _db.runTransaction((transaction) async {
        final configSnapshot = await transaction.get(_configRef);
        final userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw AppFailure(
            'No se encontró el usuario.',
            code: 'user_not_found',
          );
        }

        final data = userSnapshot.data() ?? const <String, dynamic>{};
        final stampsBefore = (data['currentStamps'] as num?)?.toInt() ?? 0;
        final displayName = (data['displayName'] as String?)?.trim() ?? '';
        final username = (data['username'] as String?)?.trim() ?? '';
        final userName = displayName.isNotEmpty
            ? displayName
            : (username.isNotEmpty ? username : 'Cliente');

        final config = ConfigModel.fromDoc(configSnapshot.data());

        transaction.update(userRef, {
          'currentStamps': 0,
          'isRewardReady': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(_db.collection('redemptions').doc(), {
          'userId': userId,
          'userName': userName,
          'stampsBefore': stampsBefore,
          'rewardDescription': config.rewardDescription,
          'redeemedBy': admin.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error) {
      throw _translate(error);
    }
  }

  // ---------------------------------------------------------------------------
  // Prueba del negocio
  // ---------------------------------------------------------------------------

  /// Lee `trial_expiry_date` de Remote Config y, si no está disponible, usa el
  /// espejo guardado en `config/main.trialExpiryDate`.
  Future<TrialStatus> checkTrialStatus() async {
    DateTime? expiry;

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.fetchAndActivate();
      expiry = _parseDate(remoteConfig.getString('trial_expiry_date'));
    } catch (_) {
      // Sin Remote Config se usa el espejo de Firestore.
    }

    if (expiry == null) {
      try {
        final snapshot = await _configRef.get();
        expiry = _parseDate(
          ConfigModel.fromDoc(snapshot.data()).trialExpiryDate,
        );
      } catch (_) {
        // Sin conexión no se bloquea la app.
      }
    }

    if (expiry == null) return TrialStatus.activeNow;

    final now = DateTime.now().toUtc();
    final active = now.isBefore(expiry);
    final days = expiry.difference(now).inDays;

    return TrialStatus(
      active: active,
      expiryDate: expiry,
      daysRemaining: days < 0 ? 0 : days,
    );
  }

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------

  User _requireAdmin() {
    final user = _auth.currentUser;
    if (user == null) {
      throw AppFailure(
        'Tu sesión expiró. Vuelve a iniciar sesión.',
        code: 'unauthenticated',
      );
    }
    return user;
  }

  static DateTime? _parseDate(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  AppFailure _translate(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return AppFailure(
          'La operación no está permitida. Si el problema continúa, revisa las reglas de Firestore.',
          code: 'permission-denied',
        );
      case 'unauthenticated':
        return AppFailure(
          'Tu sesión expiró. Vuelve a iniciar sesión.',
          code: 'unauthenticated',
        );
      case 'unavailable':
      case 'network-request-failed':
        return AppFailure(
          'Sin conexión. Revisa tu red e inténtalo de nuevo.',
          code: 'unavailable',
        );
      case 'aborted':
      case 'failed-precondition':
        return AppFailure(
          'La operación no se puede completar ahora mismo. Inténtalo de nuevo.',
          code: error.code,
        );
      case 'already-exists':
        return AppFailure(
          'Ese nombre de usuario ya está en uso. Prueba con otro.',
          code: 'username_taken',
        );
      case 'resource-exhausted':
        return AppFailure(
          'Se alcanzó un límite temporal. Inténtalo más tarde.',
          code: 'resource-exhausted',
        );
    }
    return AppFailure(
      'No se pudo completar la operación. Inténtalo de nuevo.',
      code: error.code,
    );
  }
}
