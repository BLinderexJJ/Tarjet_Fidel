import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/config_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/app_animations.dart';
import 'admin/clients_tab.dart';
import 'admin/config_tab.dart';
import 'admin/qr_tab.dart';
import 'admin/requests_tab.dart';

/// Panel del administrador con navegación lateral o inferior.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.user});

  final User user;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();
  late final Stream<ConfigModel> _configStream = _firestore.configStream();

  int _index = 0;

  static const _destinations = <NavigationDestination>[
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

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 960;

    return StreamBuilder<ConfigModel>(
      stream: _configStream,
      builder: (context, snapshot) {
        final config = snapshot.data ?? ConfigModel.defaults();
        final pages = <Widget>[
          const RequestsTab(),
          const ClientsTab(),
          ConfigTab(adminUid: widget.user.uid),
          const QrTab(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Pulse(
                  maxScale: 1.08,
                  duration: const Duration(milliseconds: 1800),
                  child: Icon(Icons.storefront_rounded, color: config.color),
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
                      const Text(
                        'Panel de administración',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
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
                      selectedIndex: _index,
                      onDestinationSelected: (index) =>
                          setState(() => _index = index),
                      labelType: MediaQuery.sizeOf(context).width >= 1200
                          ? NavigationRailLabelType.all
                          : NavigationRailLabelType.selected,
                      destinations: _destinations
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
                        index: _index,
                        children: pages,
                      ),
                    ),
                  ],
                )
              : AnimatedIndexedStack(index: _index, children: pages),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (index) =>
                      setState(() => _index = index),
                  destinations: _destinations,
                ),
        );
      },
    );
  }
}
