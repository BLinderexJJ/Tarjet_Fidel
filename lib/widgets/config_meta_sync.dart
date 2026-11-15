import 'dart:async';

import 'package:flutter/material.dart';

import '../models/config_model.dart';
import '../services/firestore_service.dart';
import '../utils/web_meta.dart';

/// Mantiene el título de la pestaña y el color del navegador sincronizados con
/// `config/main`, para que cada negocio se vea propio también fuera del canvas.
class ConfigMetaSync extends StatefulWidget {
  const ConfigMetaSync({super.key, required this.child});

  final Widget child;

  @override
  State<ConfigMetaSync> createState() => _ConfigMetaSyncState();
}

class _ConfigMetaSyncState extends State<ConfigMetaSync> {
  final FirestoreService _firestore = FirestoreService();
  StreamSubscription<ConfigModel>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _firestore.configStream().listen(
      (config) {
        applyWebMeta(title: config.businessName, themeColor: config.themeColor);
      },
      onError: (_) {
        // Si Firestore no responde se conserva el título por defecto.
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
