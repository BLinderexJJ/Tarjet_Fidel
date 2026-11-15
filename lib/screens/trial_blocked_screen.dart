import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/config_model.dart';
import '../services/backend_service.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/app_animations.dart';

/// Pantalla de bloqueo cuando la prueba del negocio ha expirado.
class TrialBlockedScreen extends StatefulWidget {
  const TrialBlockedScreen({
    super.key,
    required this.trial,
    required this.onSignOut,
  });

  final TrialStatus trial;
  final Future<void> Function() onSignOut;

  @override
  State<TrialBlockedScreen> createState() => _TrialBlockedScreenState();
}

class _TrialBlockedScreenState extends State<TrialBlockedScreen> {
  final FirestoreService _firestore = FirestoreService();
  late final Stream<ConfigModel> _configStream = _firestore.configStream();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<ConfigModel>(
        stream: _configStream,
        builder: (context, snapshot) {
          final config = snapshot.data ?? ConfigModel.defaults();
          final expiry = widget.trial.expiryDate;
          return BrandBackground(
            color: config.color,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Reveal(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 40,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Pulse(
                            maxScale: 1.06,
                            duration: const Duration(milliseconds: 1800),
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDECEC),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.lock_clock_rounded,
                                size: 38,
                                color: Color(0xFFB3261E),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'La prueba de ${config.businessName} ha terminado',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'El período de prueba de este negocio expiró. '
                            'Contacta con el administrador para reactivar el servicio.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              height: 1.45,
                            ),
                          ),
                          if (expiry != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Fecha de expiración: '
                                '${DateFormat('dd/MM/yyyy HH:mm').format(expiry.toLocal())}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                          if (config.contactInfo.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            SelectableText(
                              config.contactInfo,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: config.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 26),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => widget.onSignOut(),
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Cerrar sesión'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
