import 'package:flutter/material.dart';

import '../utils/trial.dart';

/// Documento único `config/main`.
class ConfigModel {
  const ConfigModel({
    required this.businessName,
    required this.logoUrl,
    required this.stampsGoal,
    required this.rewardDescription,
    required this.themeColor,
    required this.maxUsers,
    required this.checkinCode,
    required this.contactInfo,
    this.stampImage = '',
    this.trialExpiryDate,
  });

  final String businessName;
  final String logoUrl;

  /// Imagen que se muestra dentro de los sellos válidos.
  ///
  /// Puede ser una URL `https://…` o una URL `data:image/…;base64,…` (Spark).
  /// Si está vacía, los sellos usan el icono de check por defecto.
  final String stampImage;
  final int stampsGoal;
  final String rewardDescription;

  /// Color en formato hexadecimal, por ejemplo `#4F46E5`.
  final String themeColor;
  final int maxUsers;

  /// Código que viaja dentro del QR que muestran los administradores.
  final String checkinCode;

  /// Datos de contacto que se muestran cuando la prueba expira.
  final String contactInfo;

  /// Fecha de prueba en ISO 8601; espejo legible de `trialExpiryAt`.
  final String? trialExpiryDate;

  factory ConfigModel.fromMap(Map<String, dynamic> data) {
    return ConfigModel(
      businessName: (data['businessName'] as String?) ?? defaultBusinessName,
      logoUrl: (data['logoUrl'] as String?) ?? '',
      stampImage: (data['stampImage'] as String?) ?? '',
      stampsGoal: (data['stampsGoal'] as num?)?.toInt() ?? defaultStampsGoal,
      rewardDescription:
          (data['rewardDescription'] as String?) ?? defaultRewardDescription,
      themeColor: (data['themeColor'] as String?) ?? defaultThemeColor,
      maxUsers: (data['maxUsers'] as num?)?.toInt() ?? defaultMaxUsers,
      checkinCode: (data['checkinCode'] as String?) ?? '',
      contactInfo: (data['contactInfo'] as String?) ?? '',
      trialExpiryDate: data['trialExpiryDate'] as String?,
    );
  }

  factory ConfigModel.fromDoc(Map<String, dynamic>? data) {
    return ConfigModel.fromMap(data ?? const {});
  }

  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'logoUrl': logoUrl,
      'stampImage': stampImage,
      'stampsGoal': stampsGoal,
      'rewardDescription': rewardDescription,
      'themeColor': themeColor,
      'maxUsers': maxUsers,
      'checkinCode': checkinCode,
      'contactInfo': contactInfo,
      'trialExpiryDate': trialExpiryDate,
    };
  }

  ConfigModel copyWith({
    String? businessName,
    String? logoUrl,
    String? stampImage,
    int? stampsGoal,
    String? rewardDescription,
    String? themeColor,
    int? maxUsers,
    String? checkinCode,
    String? contactInfo,
    String? trialExpiryDate,
  }) {
    return ConfigModel(
      businessName: businessName ?? this.businessName,
      logoUrl: logoUrl ?? this.logoUrl,
      stampImage: stampImage ?? this.stampImage,
      stampsGoal: stampsGoal ?? this.stampsGoal,
      rewardDescription: rewardDescription ?? this.rewardDescription,
      themeColor: themeColor ?? this.themeColor,
      maxUsers: maxUsers ?? this.maxUsers,
      checkinCode: checkinCode ?? this.checkinCode,
      contactInfo: contactInfo ?? this.contactInfo,
      trialExpiryDate: trialExpiryDate ?? this.trialExpiryDate,
    );
  }

  /// Color listo para usar en la interfaz. Nunca lanza excepción.
  Color get color {
    final hex = themeColor.replaceAll('#', '').trim();
    final normalized = hex.length == 6
        ? hex
        : defaultThemeColor.replaceAll('#', '');
    final value = int.tryParse(normalized, radix: 16);
    if (value == null) return const Color(0xFF4F46E5);
    return Color(0xFF000000 | value);
  }

  /// Fecha de expiración de la prueba, normalizada a UTC.
  DateTime? get trialExpiry => parseTrialExpiry(trialExpiryDate);

  /// Payload que se codifica dentro del QR de check-in.
  String get checkinPayload => 'TARJET:$checkinCode';

  static const String defaultBusinessName = 'Tarjet Fidel';
  static const int defaultStampsGoal = 10;
  static const String defaultRewardDescription =
      'Completa tu tarjeta y llévate un premio.';
  static const String defaultThemeColor = '#4F46E5';
  static const int defaultMaxUsers = 50;

  static ConfigModel defaults() {
    return const ConfigModel(
      businessName: defaultBusinessName,
      logoUrl: '',
      stampImage: '',
      stampsGoal: defaultStampsGoal,
      rewardDescription: defaultRewardDescription,
      themeColor: defaultThemeColor,
      maxUsers: defaultMaxUsers,
      checkinCode: '',
      contactInfo: '',
    );
  }
}
