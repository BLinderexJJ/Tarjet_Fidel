import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_role.dart';

/// Cuenta con acceso al panel, leída desde `admins/{uid}`.
class AdminAccount {
  const AdminAccount({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final AdminRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isSuperAdmin => role.isSuperAdmin;

  factory AdminAccount.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminAccount(
      uid: doc.id,
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      role: AdminRole.fromAdminValue(data['role']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
