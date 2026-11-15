import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, client }

/// Documento de la colección `users`.
///
/// El ID del documento es el UID de Firebase Auth.
class UserModel {
  const UserModel({
    required this.uid,
    required this.username,
    required this.internalEmail,
    required this.displayName,
    required this.currentStamps,
    required this.totalVisits,
    required this.role,
    required this.isRewardReady,
    this.createdAt,
  });

  final String uid;
  final String username;
  final String internalEmail;
  final String displayName;
  final int currentStamps;
  final int totalVisits;
  final UserRole role;
  final bool isRewardReady;
  final DateTime? createdAt;

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromMap(doc.id, doc.data() ?? const {});
  }

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    final rawRole = (data['role'] as String?) ?? UserRole.client.name;
    return UserModel(
      uid: uid,
      username: (data['username'] as String?) ?? '',
      internalEmail: (data['internalEmail'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      currentStamps: (data['currentStamps'] as num?)?.toInt() ?? 0,
      totalVisits: (data['totalVisits'] as num?)?.toInt() ?? 0,
      role: rawRole == UserRole.admin.name ? UserRole.admin : UserRole.client,
      isRewardReady: (data['isRewardReady'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'usernameLower': username.toLowerCase(),
      'internalEmail': internalEmail,
      'displayName': displayName,
      'currentStamps': currentStamps,
      'totalVisits': totalVisits,
      'role': role.name,
      'isRewardReady': isRewardReady,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  UserModel copyWith({
    String? displayName,
    int? currentStamps,
    int? totalVisits,
    UserRole? role,
    bool? isRewardReady,
  }) {
    return UserModel(
      uid: uid,
      username: username,
      internalEmail: internalEmail,
      displayName: displayName ?? this.displayName,
      currentStamps: currentStamps ?? this.currentStamps,
      totalVisits: totalVisits ?? this.totalVisits,
      role: role ?? this.role,
      isRewardReady: isRewardReady ?? this.isRewardReady,
      createdAt: createdAt,
    );
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isClient => role == UserRole.client;

  /// Nombre visible con respaldo en el usuario interno.
  String get name => displayName.trim().isNotEmpty ? displayName : username;
}
