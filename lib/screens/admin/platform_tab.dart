import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/config_model.dart';
import '../../services/backend_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/trial.dart';
import '../../widgets/app_animations.dart';
import 'admins_section.dart';

/// Pestaña exclusiva del superadministrador para consultar y renovar la prueba.
class PlatformTab extends StatefulWidget {
  const PlatformTab({super.key});

  @override
  State<PlatformTab> createState() => _PlatformTabState();
}

class _PlatformTabState extends State<PlatformTab> {
  final FirestoreService _firestore = FirestoreService();
  StreamSubscription<ConfigModel>? _subscription;

  ConfigModel _config = ConfigModel.defaults();
  DateTime? _draftExpiry;
  bool _loading = true;
  bool _saving = false;
  bool _clearing = false;
  bool _draftInitialized = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = _firestore.configStream().listen(
      _handleConfig,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error =
              'No se pudo cargar el estado de la prueba. Revisa tu conexión.';
        });
      },
    );
  }

  void _handleConfig(ConfigModel config) {
    if (!mounted) return;

    final expiry = config.trialExpiry;
    setState(() {
      _config = config;
      _loading = false;
      _error = null;

      if (!_draftInitialized) {
        _draftExpiry = expiry?.toLocal() ?? _defaultDraft();
        _draftInitialized = true;
      } else if (!_dirty) {
        // Si otro superadministrador cambia la fecha, se refleja mientras el
        // usuario no tenga cambios pendientes.
        _draftExpiry = expiry?.toLocal() ?? _defaultDraft();
      }
    });
  }

  DateTime _defaultDraft() => DateTime.now().add(const Duration(days: 15));

  bool get _draftInPast {
    final draft = _draftExpiry;
    return draft != null && !draft.isAfter(DateTime.now());
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _draftExpiry ?? _defaultDraft();

    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Fecha de expiración de la prueba',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Hora de expiración',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (time == null || !mounted) return;

    setState(() {
      _draftExpiry = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _dirty = true;
    });
  }

  void _extend(int days) {
    final now = DateTime.now();
    final draft = _draftExpiry;
    final base = draft != null && draft.isAfter(now) ? draft : now;

    setState(() {
      _draftExpiry = base.add(Duration(days: days));
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final draft = _draftExpiry;
    if (draft == null || _saving || _clearing) return;

    setState(() => _saving = true);
    try {
      await _firestore.saveTrialExpiry(draft);
      if (!mounted) return;
      setState(() => _dirty = false);
      _notify(
        'Prueba actualizada hasta ${formatTrialExpiry(draft)} (hora local).',
      );
    } catch (error) {
      _notify(
        error is AppFailure
            ? error.message
            : 'No se pudo actualizar la prueba. Inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    if (_saving || _clearing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar fecha límite'),
        content: const Text(
          'La prueba quedará activa sin fecha de expiración hasta que vuelvas '
          'a fijar una. ¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar límite'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      await _firestore.clearTrialExpiry();
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _draftExpiry = _defaultDraft();
        _draftInitialized = true;
      });
      _notify('La prueba ya no tiene fecha límite.');
    } catch (error) {
      _notify(
        error is AppFailure
            ? error.message
            : 'No se pudo quitar la fecha límite. Inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _listen();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _retry, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final expiry = _config.trialExpiry;
    final active = trialIsActive(expiry);
    final remaining = trialRemainingLabel(expiry);
    final draft = _draftExpiry ?? _defaultDraft();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plataforma',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Controla la vigencia de la prueba del negocio.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                if (_dirty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFF5D48A)),
                    ),
                    child: const Text(
                      'Cambios sin guardar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A5A00),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Reveal(
              child: _StatusCard(
                active: active,
                expiry: expiry,
                remaining: remaining,
                color: _config.color,
              ),
            ),
            const SizedBox(height: 16),
            Reveal(
              delay: const Duration(milliseconds: 60),
              child: _Section(
                title: 'Nueva fecha de expiración',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _saving || _clearing ? null : _pickDateTime,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_rounded, color: _config.color),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatTrialExpiry(draft),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Hora local · toca para cambiar fecha y hora',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.edit_calendar_rounded,
                              color: Colors.black38,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_draftInPast) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF5B5B5)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFB3261E),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'La fecha elegida ya pasó: la prueba quedará '
                                'vencida inmediatamente al guardar.',
                                style: TextStyle(
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final days in const [7, 15, 30, 90])
                          OutlinedButton.icon(
                            onPressed: _saving || _clearing
                                ? null
                                : () => _extend(days),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text('+$days días'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving || _clearing ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              _saving ? 'Guardando…' : 'Guardar fecha',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _saving || _clearing ? null : _clear,
                          icon: _clearing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.all_inclusive_rounded),
                          label: Text(_clearing ? 'Quitando…' : 'Sin límite'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Reveal(
              delay: const Duration(milliseconds: 120),
              child: _InfoCard(color: _config.color),
            ),
            const SizedBox(height: 16),
            AdminsSection(color: _config.color),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.active,
    required this.expiry,
    required this.remaining,
    required this.color,
  });

  final bool active;
  final DateTime? expiry;
  final String remaining;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final accent = active ? const Color(0xFF10B981) : const Color(0xFFB3261E);

    return HoverLift(
      scale: 1.005,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: active
                ? [color.withValues(alpha: 0.12), Colors.white]
                : [const Color(0xFFFDECEC), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Pulse(
              enabled: active,
              maxScale: 1.06,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  active
                      ? Icons.verified_user_rounded
                      : Icons.lock_clock_rounded,
                  color: accent,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active ? 'Prueba activa' : 'Prueba vencida',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    remaining,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    expiry == null
                        ? 'Sin fecha de expiración configurada.'
                        : 'Expira el ${formatTrialExpiry(expiry!)} '
                              '(hora local).',
                    style: const TextStyle(color: Colors.black54, height: 1.35),
                  ),
                  if (expiry != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'UTC: ${expiry!.toUtc().toIso8601String()}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      child: HoverLift(
        scale: 1.005,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: color),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'La fecha se guarda en Firestore (config/main.trialExpiryAt) y '
              'las reglas la aplican al instante. Remote Config solo se usa '
              'como respaldo si no hay fecha en Firestore. Al guardar, los '
              'clientes y el panel del negocio se desbloquean sin recompilar.',
              style: TextStyle(
                color: Colors.black54,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
