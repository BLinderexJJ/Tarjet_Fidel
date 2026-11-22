import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/config_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/codes.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/qr_display.dart';

/// Pestaña que muestra el QR que escanean los clientes.
class QrTab extends StatefulWidget {
  const QrTab({super.key});

  @override
  State<QrTab> createState() => _QrTabState();
}

class _QrTabState extends State<QrTab> {
  final FirestoreService _firestore = FirestoreService();
  late final Stream<ConfigModel> _configStream = _firestore.configStream();
  bool _saving = false;

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyCode(ConfigModel config) async {
    if (config.checkinCode.isEmpty) {
      _notify('Primero genera un código de check-in.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: config.checkinCode));
    _notify('Código copiado: ${config.checkinCode}');
  }

  Future<void> _regenerate() async {
    if (_saving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar un código nuevo'),
        content: const Text(
          'El QR actual dejará de ser válido. Tendrás que imprimir o mostrar '
          'el nuevo código a tus clientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generar nuevo'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final code = generateCheckinCode();
      await _firestore.updateConfigField('checkinCode', code);
      _notify('Nuevo código generado: $code');
    } catch (_) {
      _notify('No se pudo generar el código. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConfigModel>(
      stream: _configStream,
      builder: (context, snapshot) {
        final loaded = snapshot.hasData;
        final config = snapshot.data ?? ConfigModel.defaults();
        final hasCode = loaded && config.checkinCode.trim().isNotEmpty;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              children: [
                const Reveal(
                  child: Text(
                    'QR de check-in',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 4),
                const Reveal(
                  delay: Duration(milliseconds: 60),
                  child: Text(
                    'Muestra este QR en el mostrador. Los clientes lo escanean '
                    'para solicitar un sello.',
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                ),
                const SizedBox(height: 24),
                Reveal(
                  delay: const Duration(milliseconds: 100),
                  child: HoverLift(
                    scale: 1.008,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        children: [
                          QrDisplay(
                            code: config.checkinCode,
                            color: config.color,
                          ),
                          const SizedBox(height: 18),
                          if (hasCode)
                            ShimmerHighlight(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F6FA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Código: ',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                    SelectableText(
                                      config.checkinCode,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 3,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            const Text(
                              'Todavía no hay un código generado.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: hasCode
                                    ? () => _copyCode(config)
                                    : null,
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('Copiar código'),
                              ),
                              FilledButton.icon(
                                onPressed: !loaded || _saving
                                    ? null
                                    : _regenerate,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded),
                                label: Text(
                                  _saving
                                      ? 'Generando…'
                                      : hasCode
                                      ? 'Generar nuevo código'
                                      : 'Generar código',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Reveal(
                  delay: const Duration(milliseconds: 160),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cómo funciona',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. El cliente entra con su usuario y escanea este QR.\n'
                          '2. Se crea una solicitud pendiente, nunca un sello directo.\n'
                          '3. Tú la apruebas desde la pestaña Solicitudes y el sello '
                          'aparece en la tarjeta del cliente al instante.',
                          style: TextStyle(
                            color: Colors.black54,
                            height: 1.5,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Reveal(
                  delay: Duration(milliseconds: 220),
                  child: Text(
                    'Consejo: si el QR se filtra o quieres invalidarlo, genera un '
                    'código nuevo. Los QR antiguos dejarán de funcionar.',
                    style: TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
