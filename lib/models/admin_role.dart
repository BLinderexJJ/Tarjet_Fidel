/// Rol efectivo de una cuenta administrativa.
///
/// - [none]: la cuenta no tiene documento en `admins/{uid}`.
/// - [admin]: administrador del negocio (dueño o encargado).
/// - [superadmin]: dueño de la plataforma (programador). Puede renovar la
///   prueba y, además, usar todas las funciones del administrador del negocio.
enum AdminRole {
  none,
  admin,
  superadmin;

  bool get isAdmin => this != AdminRole.none;

  bool get isSuperAdmin => this == AdminRole.superadmin;

  /// Interpreta el campo `role` de `admins/{uid}`.
  ///
  /// Los documentos antiguos no tienen `role`; se consideran administradores
  /// del negocio para no romper instalaciones existentes.
  static AdminRole fromAdminValue(Object? value) {
    final raw = value is String ? value.trim().toLowerCase() : '';
    return raw == 'superadmin' ? AdminRole.superadmin : AdminRole.admin;
  }
}
