import 'package:flutter/material.dart';

import '../../models/config_model.dart';
import '../../models/user_model.dart';
import '../../services/backend_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/motion.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/confetti_burst.dart';

/// Pestaña con los clientes del negocio y el canje de premios.
class ClientsTab extends StatefulWidget {
  const ClientsTab({super.key});

  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  final FirestoreService _firestore = FirestoreService();
  final BackendService _backend = BackendService();
  late final Stream<List<UserModel>> _clientsStream = _firestore
      .clientsStream();
  late final Stream<ConfigModel> _configStream = _firestore.configStream();

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _busyUid;
  int _celebration = 0;

  void _celebrate() {
    if (mounted) setState(() => _celebration += 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _resetStamps(UserModel user, {required int goal}) async {
    final safeGoal = goal.clamp(1, 100);
    final ready = user.isRewardReadyFor(safeGoal);
    final progress = '${user.currentStamps} / $safeGoal';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ready ? 'Canjear premio' : 'Canjear antes de completar'),
        content: Text(
          ready
              ? '¿Canjear el premio de ${user.name}? '
                    'Sus sellos se reiniciarán a 0 y el historial se conserva.'
              : '${user.name} todavía no completó la tarjeta ($progress). '
                    'Si canjeas ahora, sus sellos se reiniciarán a 0 y perderá '
                    'el progreso.\n\n¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(ready ? 'Canjear premio' : 'Canjear de todos modos'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyUid = user.uid);
    try {
      await _backend.resetStamps(userId: user.uid);
      if (!mounted) return;
      _celebrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sellos de ${user.name} reiniciados.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AppFailure
                ? error.message
                : 'No se pudieron reiniciar los sellos.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConfigModel>(
      stream: _configStream,
      builder: (context, configSnapshot) {
        final config = configSnapshot.data ?? ConfigModel.defaults();

        return StreamBuilder<List<UserModel>>(
          stream: _clientsStream,
          builder: (context, snapshot) {
            final clients = snapshot.data ?? const <UserModel>[];
            final query = _query.trim().toLowerCase();
            final filtered = query.isEmpty
                ? clients
                : clients
                      .where(
                        (client) =>
                            client.name.toLowerCase().contains(query) ||
                            client.username.toLowerCase().contains(query),
                      )
                      .toList();

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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Clientes',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Container(
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
                                      '${clients.length} / ${config.maxUsers}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Canjea el premio de un cliente cuando lo reclame.',
                                style: TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _searchController,
                                onChanged: (value) =>
                                    setState(() => _query = value),
                                decoration: InputDecoration(
                                  hintText: 'Buscar por nombre o usuario…',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: _query.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Limpiar',
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _query = '');
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: snapshot.hasError
                              ? const _EmptyState(
                                  icon: Icons.cloud_off_rounded,
                                  text:
                                      'No se pudo cargar la lista de clientes. Revisa tu conexión.',
                                )
                              : filtered.isEmpty
                              ? _EmptyState(
                                  icon: Icons.people_outline_rounded,
                                  text: clients.isEmpty
                                      ? 'Aún no hay clientes registrados.'
                                      : 'No hay clientes que coincidan con la búsqueda.',
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    4,
                                    24,
                                    32,
                                  ),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final client = filtered[index];
                                    return StaggeredReveal(
                                      index: index,
                                      child: _ClientTile(
                                        client: client,
                                        goal: config.stampsGoal,
                                        color: config.color,
                                        busy: _busyUid == client.uid,
                                        onRedeem: () => _resetStamps(
                                          client,
                                          goal: config.stampsGoal,
                                        ),
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
      },
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({
    required this.client,
    required this.goal,
    required this.color,
    required this.busy,
    required this.onRedeem,
  });

  final UserModel client;
  final int goal;
  final Color color;
  final bool busy;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final safeGoal = goal.clamp(1, 100);
    final progress = (client.currentStamps / safeGoal).clamp(0.0, 1.0);
    final rewardReady = client.isRewardReadyFor(safeGoal);

    return HoverLift(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text(
                _initials(client.name),
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          client.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (rewardReady) ...[
                        const SizedBox(width: 8),
                        Pulse(
                          maxScale: 1.06,
                          duration: const Duration(milliseconds: 1400),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3D6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Premio listo',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8A5A13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${client.username} · ${client.totalVisits} visitas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: prefersReducedMotion(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) {
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 6,
                                backgroundColor: Colors.black12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${client.currentStamps} / $safeGoal',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PopupMenuButton<String>(
                    tooltip: 'Acciones',
                    onSelected: (value) {
                      if (value == 'redeem') onRedeem();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'redeem',
                        child: Row(
                          children: [
                            Icon(Icons.card_giftcard_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Canjear premio'),
                          ],
                        ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

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
              const SizedBox(height: 12),
              Text(
                text,
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
