import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/backend_service.dart';
import '../utils/codes.dart';
import 'manual_code_input.dart';

/// Diálogo de escaneo de QR con cámara del navegador y entrada manual.
class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({super.key, required this.onSubmit});

  /// Crea la solicitud de sello. Debe lanzar una excepción si falla.
  final Future<void> Function(String code) onSubmit;

  static Future<bool?> show(
    BuildContext context, {
    required Future<void> Function(String code) onSubmit,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QrScannerDialog(onSubmit: onSubmit),
    );
  }

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _manualMode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _switchMode(bool manual) async {
    if (_manualMode == manual) return;
    setState(() {
      _manualMode = manual;
      _error = null;
    });
    try {
      if (manual) {
        await _controller.stop();
      } else {
        await _controller.start();
      }
    } catch (_) {
      // El errorBuilder del escáner muestra la alternativa manual.
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _manualMode) return;

    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null) return;

    final code = normalizeCheckinCode(raw);
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _controller.stop();
    } catch (_) {
      // Sin cámara activa no hay nada que detener.
    }

    try {
      await widget.onSubmit(code);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is AppFailure
            ? error.message
            : 'No se pudo enviar la solicitud. Inténtalo de nuevo.';
      });
    }
  }

  Future<void> _retryCamera() async {
    setState(() => _error = null);
    try {
      await _controller.start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo iniciar la cámara. Usa el código manual.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Escanear QR del negocio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.camera_alt_rounded),
                    label: Text('Cámara'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.keyboard_rounded),
                    label: Text('Código'),
                  ),
                ],
                selected: {_manualMode},
                onSelectionChanged: (selection) => _switchMode(selection.first),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: _manualMode
                    ? SingleChildScrollView(
                        child: ManualCodeInput(
                          autofocus: true,
                          onSubmit: (code) async {
                            await widget.onSubmit(code);
                            if (!context.mounted) return;
                            Navigator.of(context).pop(true);
                          },
                        ),
                      )
                    : _buildCamera(context),
              ),
              if (_error != null && !_manualMode) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCamera(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraErrorView(
                message:
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'No diste permiso para usar la cámara. Puedes escribir el código manualmente.'
                    : 'No se pudo abrir la cámara de este dispositivo.',
                onManual: () => _switchMode(true),
                onRetry: _retryCamera,
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
            if (_busy)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 14),
                      Text(
                        'Enviando solicitud…',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({
    required this.message,
    required this.onManual,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onManual;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1F2937),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.no_photography_rounded,
            color: Colors.white70,
            size: 44,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onManual,
            icon: const Icon(Icons.keyboard_rounded),
            label: const Text('Escribir código manualmente'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Reintentar cámara',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
