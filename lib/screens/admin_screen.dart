import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/admin_role.dart';
import '../models/config_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/trial.dart';
import '../widgets/app_animations.dart';
import 'admin/clients_tab.dart';
import 'admin/config_tab.dart';
import 'admin/platform_tab.dart';
import 'admin/qr_tab.dart';
import 'admin/requests_tab.dart';

/// Panel del administrador con navegación lateral o inferior.
///
/// El superadministrador (dueño de la plataforma) ve una pestaña adicional,
/// **Plataforma**, desde la que puede consultar y renovar la prueba.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.user, required this.role});

  final User user;
  final AdminRole role;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();
  late final Stream<ConfigModel> _configStream = _firestore.configStream();

  int _index = 0;

  bool get _isSuperAdmin => widget.role.isSuperAdmin;

  static const _baseDestinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.pending_actions_outlined),
      selectedIcon: Icon(Icons.pending_actions_rounded),
      label: 'Solicitudes',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline_rounded),
      selectedIcon: Icon(Icons.people_rounded),
      label: 'Clientes',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Configuración',
    ),
    NavigationDestination(
      icon: Icon(Icons.qr_code_2_outlined),
      selectedIcon: Icon(Icons.qr_code_2_rounded),
      label: 'QR',
    ),
  ];

  List<NavigationDestination> get _destinations => [
    ..._baseDestinations,
    if (_isSuperAdmin)
      const NavigationDestination(
        icon: Icon(Icons.shield_outlined),
        selectedIcon: Icon(Icons.shield_rounded),
        label: 'Plataforma',
      ),
  ];

  List<Widget> _buildPages() => [
    const RequestsTab(),
    const ClientsTab(),
    ConfigTab(adminUid: widget.user.uid),
    const QrTab(),
    if (_isSuperAdmin) const PlatformTab(),
  ];

  int get _platformIndex => _destinations.length - 1;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 960;

    return StreamBuilder<ConfigModel>(
      stream: _configStream,
      builder: (context, snapshot) {
        final config = snapshot.data ?? ConfigModel.defaults();
        final destinations = _destinations;
        final pages = _buildPages();
        final index = _index < destinations.length ? _index : 0;
        final trialActive = trialIsActive(config.trialExpiry);

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Pulse(
                  maxScale: 1.08,
                  duration: const Duration(milliseconds: 1800),
                  child: Icon(
                    _isSuperAdmin
                        ? Icons.shield_rounded
                        : Icons.storefront_rounded,
                    color: config.color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        config.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _isSuperAdmin
                                ? 'Panel de plataforma'
                                : 'Panel de administración',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.black54,
                            ),
                          ),
                          if (_isSuperAdmin && isWide) ...[
                            const SizedBox(width: 8),
                            _RoleBadge(color: config.color),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (_isSuperAdmin)
                if (isWide)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: ActionChip(
                        avatar: Icon(
                          trialActive
                              ? Icons.verified_user_rounded
                              : Icons.lock_clock_rounded,
                          size: 18,
                          color: trialActive
                              ? const Color(0xFF10B981)
                              : const Color(0xFFB3261E),
                        ),
                        label: Text(
                          trialRemainingLabel(config.trialExpiry),
                          style: TextStyle(
                            fontSize: 12,
                            color: trialActive
                                ? Colors.black87
                                : const Color(0xFFB3261E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () =>
                            setState(() => _index = _platformIndex),
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: trialActive
                        ? 'Prueba: ${trialRemainingLabel(config.trialExpiry)}'
                        : 'Prueba vencida · gestionar',
                    onPressed: () => setState(() => _index = _platformIndex),
                    icon: Icon(
                      trialActive
                          ? Icons.shield_rounded
                          : Icons.gpp_bad_rounded,
                      color: trialActive ? null : const Color(0xFFB3261E),
                    ),
                  ),
              if (isWide)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Text(
                      widget.user.email ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: () => _auth.signOut(),
                icon: const Icon(Icons.logout_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: index,
                      onDestinationSelected: (selected) =>
                          setState(() => _index = selected),
                      labelType: MediaQuery.sizeOf(context).width >= 1200
                          ? NavigationRailLabelType.all
                          : NavigationRailLabelType.selected,
                      destinations: destinations
                          .map(
                            (destination) => NavigationRailDestination(
                              icon: destination.icon,
                              selectedIcon: destination.selectedIcon,
                              label: Text(destination.label),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: AnimatedIndexedStack(
                        index: index,
                        children: pages,
                      ),
                    ),
                  ],
                )
              : AnimatedIndexedStack(index: index, children: pages),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (selected) =>
                      setState(() => _index = selected),
                  destinations: destinations,
                ),
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'SUPERADMIN',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}
