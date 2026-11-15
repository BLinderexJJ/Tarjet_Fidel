import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/config_model.dart';
import '../models/stamp_request_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/firestore_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/loyalty_card.dart';
import '../widgets/qr_scanner_widget.dart';

/// Pantalla del cliente: su tarjeta, solicitud de sellos e historial.
class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key, required this.user});

  final User user;

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();
  final BackendService _backend = BackendService();

  late final Stream<ConfigModel> _configStream = _firestore.configStream();
  late final Stream<UserModel?> _userStream = _firestore.userStream(
    widget.user.uid,
  );
  late final Stream<List<StampRequestModel>> _requestsStream = _firestore
      .myRequestsStream(widget.user.uid);
  late final Stream<List<VisitModel>> _visitsStream = _firestore
      .recentVisitsStream(widget.user.uid);

  bool _openingScanner = false;

  Future<void> _openScanner() async {
    if (_openingScanner) return;
    setState(() => _openingScanner = true);

    try {
      final result = await QrScannerDialog.show(
        context,
        onSubmit: (code) async {
          await _backend.createStampRequest(code: code);
        },
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solicitud enviada. Espera la aprobación del administrador.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingScanner = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConfigModel>(
      stream: _configStream,
      builder: (context, configSnapshot) {
        final config = configSnapshot.data ?? ConfigModel.defaults();

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.storefront_rounded, color: config.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    config.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: () => _auth.signOut(),
                icon: const Icon(Icons.logout_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: StreamBuilder<UserModel?>(
            stream: _userStream,
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting &&
                  !userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final user = userSnapshot.data;
              if (user == null) {
                return _MissingProfile(onSignOut: _auth.signOut);
              }

              return StreamBuilder<List<StampRequestModel>>(
                stream: _requestsStream,
                builder: (context, requestsSnapshot) {
                  final requests = requestsSnapshot.data ?? const [];
                  final pending = requests.where((r) => r.isPending).toList();
                  final hasPending = pending.isNotEmpty;
                  final lastRejected =
                      requests.isNotEmpty &&
                      requests.first.isRejected &&
                      !hasPending;

                  return StreamBuilder<List<VisitModel>>(
                    stream: _visitsStream,
                    builder: (context, visitsSnapshot) {
                      final visits = visitsSnapshot.data ?? const [];
                      final rewardReady = user.isRewardReadyFor(
                        config.stampsGoal,
                      );

                      return CelebrationOnChange(
                        value: user.currentStamps,
                        enabled: user.isClient,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                              children: [
                                LoyaltyCard(
                                  user: user,
                                  config: config,
                                  animateStamps: true,
                                ),
                                const SizedBox(height: 20),
                                if (hasPending)
                                  Reveal(
                                    delay: const Duration(milliseconds: 80),
                                    child: _PendingBanner(
                                      request: pending.first,
                                      color: config.color,
                                    ),
                                  )
                                else if (rewardReady)
                                  Reveal(
                                    delay: const Duration(milliseconds: 80),
                                    child: _RewardBanner(color: config.color),
                                  )
                                else
                                  Reveal(
                                    delay: const Duration(milliseconds: 80),
                                    child: _ActionCard(
                                      color: config.color,
                                      busy: _openingScanner,
                                      onScan: _openScanner,
                                    ),
                                  ),
                                if (lastRejected) ...[
                                  const SizedBox(height: 14),
                                  const Reveal(
                                    delay: Duration(milliseconds: 140),
                                    child: _InfoBanner(
                                      icon: Icons.info_outline_rounded,
                                      text:
                                          'Tu última solicitud fue rechazada. '
                                          'Puedes volver a escanear el QR del negocio.',
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 28),
                                Reveal(
                                  delay: const Duration(milliseconds: 180),
                                  child: Row(
                                    children: [
                                      const Text(
                                        'Últimas visitas',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${user.totalVisits} en total',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (visits.isEmpty)
                                  const Reveal(
                                    delay: Duration(milliseconds: 220),
                                    child: _EmptyVisits(),
                                  )
                                else
                                  ...List.generate(
                                    visits.length,
                                    (index) => StaggeredReveal(
                                      index: index,
                                      child: _VisitTile(visit: visits[index]),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.color,
    required this.busy,
    required this.onScan,
  });

  final Color color;
  final bool busy;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Consigue un sello',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Escanea el QR que muestra el negocio para enviar una solicitud. '
              'El administrador la aprobará y el sello aparecerá aquí.',
              style: TextStyle(color: Colors.black54, height: 1.45),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : onScan,
              style: FilledButton.styleFrom(backgroundColor: color),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.qr_code_scanner_rounded),
              label: Text(busy ? 'Abriendo cámara…' : 'Escanear QR'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.request, required this.color});

  final StampRequestModel request;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final created = request.createdAt;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3D9A4)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFFB7791F),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solicitud pendiente',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A5A13),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  created == null
                      ? 'Espera la aprobación del administrador.'
                      : 'Enviada el ${DateFormat('dd/MM/yyyy HH:mm').format(created.toLocal())}. '
                            'Espera la aprobación del administrador.',
                  style: const TextStyle(
                    color: Color(0xFF8A5A13),
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardBanner extends StatelessWidget {
  const _RewardBanner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC94D), Color(0xFFFFA726)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33FF9800),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Pulse(
            maxScale: 1.12,
            duration: Duration(milliseconds: 1200),
            child: Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFF5B3A00),
              size: 40,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Tienes un premio listo!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5B3A00),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Muéstrale esta pantalla al administrador para canjearlo.',
                  style: TextStyle(color: Color(0xFF5B3A00), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF3B5BDB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF3B5BDB),
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

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.visit});

  final VisitModel visit;

  @override
  Widget build(BuildContext context) {
    final date = visit.timestamp;
    return HoverLift(
      scale: 1.01,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF3FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 20,
                color: Color(0xFF3B5BDB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '+${visit.stamps} ${visit.stamps == 1 ? 'sello' : 'sellos'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              date == null
                  ? '—'
                  : DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal()),
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyVisits extends StatelessWidget {
  const _EmptyVisits();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: const Text(
        'Todavía no tienes visitas registradas. Escanea el QR del negocio para empezar.',
        style: TextStyle(color: Colors.black54, height: 1.45),
      ),
    );
  }
}

class _MissingProfile extends StatelessWidget {
  const _MissingProfile({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_rounded,
              size: 48,
              color: Colors.black38,
            ),
            const SizedBox(height: 12),
            const Text(
              'No encontramos tu perfil de cliente. Vuelve a iniciar sesión o contacta con el negocio.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => onSignOut(),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
