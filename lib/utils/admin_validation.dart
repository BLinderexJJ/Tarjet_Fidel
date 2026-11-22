// Validaciones compartidas por el alta de administradores de negocio.
// Se mantienen fuera del widget para poder probarlas sin Firebase.

/// El correo de un administrador debe ser real: los clientes usan el dominio
/// sintético `tarjetfidel.local` y no deben mezclarse con cuentas de admin.
String? validateAdminEmail(String? value) {
  final email = value?.trim().toLowerCase() ?? '';
  if (email.isEmpty) return 'Escribe el correo del administrador.';
  final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  if (!emailPattern.hasMatch(email)) return 'Escribe un correo válido.';
  if (email.endsWith('.local')) {
    return 'Usa un correo real; .local está reservado para clientes.';
  }
  return null;
}

String? validateAdminDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Escribe el nombre visible.';
  if (name.length < 2) return 'El nombre es demasiado corto.';
  if (name.length > 60) return 'El nombre no puede superar 60 caracteres.';
  return null;
}

String? validateAdminPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Escribe una contraseña.';
  if (password.length < 8) return 'Usa al menos 8 caracteres.';
  if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
    return 'Incluye al menos una letra.';
  }
  if (!RegExp(r'\d').hasMatch(password)) {
    return 'Incluye al menos un número.';
  }
  return null;
}
