import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/backend_service.dart';
import '../utils/codes.dart';

/// Campo de texto para introducir el código del QR sin usar la cámara.
class ManualCodeInput extends StatefulWidget {
  const ManualCodeInput({
    super.key,
    required this.onSubmit,
    this.initialCode,
    this.autofocus = false,
    this.submitLabel = 'Enviar solicitud',
  });

  /// Debe lanzar una excepción si el envío falla.
  final Future<void> Function(String code) onSubmit;
  final String? initialCode;
  final bool autofocus;
  final String submitLabel;

  @override
  State<ManualCodeInput> createState() => _ManualCodeInputState();
}

class _ManualCodeInputState extends State<ManualCodeInput> {
  late final TextEditingController _controller;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    final code = normalizeCheckinCode(_controller.text);
    if (code.isEmpty) {
      setState(() => _error = 'Escribe el código que aparece bajo el QR.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.onSubmit(code);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppFailure
            ? error.message
            : 'No se pudo enviar la solicitud. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          enabled: !_loading,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9:_\-?=&.]')),
            LengthLimitingTextInputFormatter(120),
          ],
          decoration: InputDecoration(
            labelText: 'Código de check-in',
            hintText: 'Ej: AB12CD',
            prefixIcon: const Icon(Icons.qr_code_2_rounded),
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: Text(_loading ? 'Enviando…' : widget.submitLabel),
        ),
      ],
    );
  }
}
