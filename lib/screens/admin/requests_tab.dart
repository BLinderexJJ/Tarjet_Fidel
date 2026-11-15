import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/stamp_request_model.dart';
import '../../services/backend_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/confetti_burst.dart';

/// Pestaña con las solicitudes de sello pendientes en tiempo real.
class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  final FirestoreService _firestore = FirestoreService();
  late final Stream<List<StampRequestModel>> _requestsStream = _firestore
      .pendingRequestsStream();
  int _celebration = 0;

  void _celebrate() {
    if (mounted) setState(() => _celebration += 1);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StampRequestModel>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <StampRequestModel>[];
        final hasError = snapshot.hasError;

        return Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Solicitudes pendientes',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Aprueba o rechaza las visitas que envían los clientes.',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          Pulse(
                            enabled: requests.isNotEmpty,
                            maxScale: 1.06,
                            duration: const Duration(milliseconds: 1400),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${requests.length}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: hasError
                          ? const _CenteredMessage(
                              icon: Icons.cloud_off_rounded,
                              title: 'No se pudieron cargar las solicitudes',
                              subtitle:
                                  'Revisa tu conexión. Las reglas de Firestore deben estar desplegadas.',
                            )
                          : requests.isEmpty
                          ? const _CenteredMessage(
                              icon: Icons.task_alt_rounded,
                              title: 'Todo al día',
                              subtitle:
                                  'No hay solicitudes pendientes en este momento.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                              itemCount: requests.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return StaggeredReveal(
                                  index: index,
                                  child: _RequestTile(
                                    request: requests[index],
                                    onApproved: _celebrate,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(child: ConfettiBurst(trigger: _celebration)),
          ],
        );
      },
    );
  }
}

class _RequestTile extends StatefulWidget {
  const _RequestTile({required this.request, required this.onApproved});

  final StampRequestModel request;
  final VoidCallback onApproved;

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  final BackendService _backend = BackendService();
  late int _stamps = widget.request.stampsAwarded.clamp(1, 10);
  bool _busy = false;

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _approve() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _backend.approveStampRequest(
        requestId: widget.request.id,
        stampsAwarded: _stamps,
      );
      widget.onApproved();
      _notify(
        'Solicitud aprobada: ${_stamps == 1 ? '1 sello' : '$_stamps sellos'} '
        'para ${widget.request.userName}.',
      );
    } catch (error) {
      _notify(
        error is AppFailure
            ? error.message
            : 'No se pudo aprobar la solicitud.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: Text(
          '¿Rechazar la solicitud de ${widget.request.userName}? '
          'El cliente podrá volver a escanear el QR.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _backend.rejectStampRequest(requestId: widget.request.id);
      _notify('Solicitud rechazada.');
    } catch (error) {
      _notify(
        error is AppFailure
            ? error.message
            : 'No se pudo rechazar la solicitud.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = widget.request.createdAt;
    final color = Theme.of(context).colorScheme.primary;

    return HoverLift(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Text(
                    _initials(widget.request.userName),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.request.userName.isEmpty
                            ? 'Cliente'
                            : widget.request.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        createdAt == null
                            ? 'Fecha pendiente'
                            : DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(createdAt.toLocal()),
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Pulse(
                  maxScale: 1.04,
                  duration: const Duration(milliseconds: 1600),
                  child: const _StatusChip(
                    label: 'Pendiente',
                    color: Color(0xFFB7791F),
                    background: Color(0xFFFFF7E6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          'Sellos:',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar sello',
                        visualDensity: VisualDensity.compact,
                        onPressed: _busy || _stamps <= 1
                            ? null
                            : () => setState(() => _stamps--),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      Text(
                        '$_stamps',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Añadir sello',
                        visualDensity: VisualDensity.compact,
                        onPressed: _busy || _stamps >= 10
                            ? null
                            : () => setState(() => _stamps++),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _approve,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_busy ? 'Procesando…' : 'Aprobar'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _reject,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Rechazar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first;
    final last = parts.last.substring(0, 1).toUpperCase();
    return '$first$last';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pulse(
                maxScale: 1.06,
                duration: const Duration(milliseconds: 1800),
                child: Icon(icon, size: 56, color: Colors.black26),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
