import 'package:cloud_firestore/cloud_firestore.dart';

enum StampRequestStatus { pending, approved, rejected }

/// Documento de la colección `stamp_requests`.
class StampRequestModel {
  const StampRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.status,
    required this.stampsAwarded,
    this.createdAt,
    this.approvedAt,
    this.rejectedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final StampRequestStatus status;
  final int stampsAwarded;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;

  factory StampRequestModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return StampRequestModel.fromMap(doc.id, doc.data() ?? const {});
  }

  factory StampRequestModel.fromMap(String id, Map<String, dynamic> data) {
    return StampRequestModel(
      id: id,
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? '',
      status: _parseStatus(data['status'] as String?),
      stampsAwarded: (data['stampsAwarded'] as num?)?.toInt() ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
    );
  }

  static StampRequestStatus _parseStatus(String? value) {
    switch (value) {
      case 'approved':
        return StampRequestStatus.approved;
      case 'rejected':
        return StampRequestStatus.rejected;
      default:
        return StampRequestStatus.pending;
    }
  }

  bool get isPending => status == StampRequestStatus.pending;
  bool get isApproved => status == StampRequestStatus.approved;
  bool get isRejected => status == StampRequestStatus.rejected;
}

/// Documento de la colección `visits` (historial inmutable).
class VisitModel {
  const VisitModel({
    required this.id,
    required this.userId,
    required this.stamps,
    this.approvedBy,
    this.timestamp,
  });

  final String id;
  final String userId;
  final int stamps;
  final String? approvedBy;
  final DateTime? timestamp;

  factory VisitModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return VisitModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      stamps: (data['stamps'] as num?)?.toInt() ?? 0,
      approvedBy: data['approvedBy'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}
