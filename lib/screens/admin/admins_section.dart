import 'package:flutter/material.dart';

import '../../models/admin_account.dart';
import '../../services/admin_management_service.dart';
import '../../services/backend_service.dart';
import '../../utils/admin_validation.dart';
import '../../widgets/app_animations.dart';

/// Alta y listado de administradores de negocio, visible solo para el
/// superadministrador dentro de la pestaña Plataforma.
class AdminsSection extends StatefulWidget {
  const AdminsSection({super.key, required this.color});

  final Color color;

  @override
  State<AdminsSection> createState() => _AdminsSectionState();
}

class _AdminsSectionState extends State<AdminsSection> {
  final AdminManagementService _service = AdminManagementService();
  late final Stream<List<AdminAccount>> _adminStream = _service.adminStream();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_creating) return;
    if (!_formKey.currentState!.validate()) return;

    final confirm = _confirmController.text;
    final password = _passwordController.text;
    if (confirm != password) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      await _service.createBusinessAdmin(
        displayName: _nameController.text,
        email: _emailController.text,
        password: password,
      );
      if (!mounted) return;
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmController.clear();
      _formKey.currentState!.reset();
      _notify(
        'Administrador creado. Ya puede iniciar sesión con su correo y contraseña.',
      );
    } on AppFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo crear el administrador.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Reveal(
      delay: const Duration(milliseconds: 180),
      child: HoverLift(
        scale: 1.003,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: widget.color),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Administradores de negocio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Crea cuentas adicionales para el dueño o encargados. Cada uno '
                'entra con su correo y contraseña y tiene acceso completo al '
                'panel del negocio, excepto la gestión de la prueba.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      enabled: !_creating,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Nombre visible',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: validateAdminDisplayName,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_creating,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: validateAdminEmail,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_creating,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText:
                            'Contraseña (mínimo 8 caracteres y un número)',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: validateAdminPassword,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      enabled: !_creating,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Repetir contraseña',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Repite la contraseña.';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF5B5B5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFB3261E),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFB3261E),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _creating ? null : _submit,
                        icon: _creating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(
                          _creating ? 'Creando…' : 'Crear administrador',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Text(
                'Cuentas actuales',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.color,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<AdminAccount>>(
                stream: _adminStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No se pudo cargar la lista de administradores.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }
                  final admins = snapshot.data ?? const <AdminAccount>[];
                  if (admins.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Todavía no hay administradores registrados.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: admins.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final admin = admins[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: widget.color.withValues(alpha: 0.12),
                          child: Icon(
                            admin.isSuperAdmin
                                ? Icons.shield_rounded
                                : Icons.storefront_rounded,
                            color: widget.color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          admin.displayName.isEmpty
                              ? admin.email
                              : admin.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(admin.email),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: admin.isSuperAdmin
                                ? widget.color.withValues(alpha: 0.12)
                                : const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            admin.isSuperAdmin ? 'SUPERADMIN' : 'NEGOCIO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: admin.isSuperAdmin
                                  ? widget.color
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
