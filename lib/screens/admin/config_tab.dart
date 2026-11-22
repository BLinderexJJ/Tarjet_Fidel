import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_config.dart';
import '../../models/config_model.dart';
import '../../services/backend_service.dart';
import '../../services/firestore_service.dart';
import '../../services/logo_service.dart';
import '../../utils/codes.dart';
import '../../utils/trial.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/logo_image.dart';

/// Pestaña para editar la configuración del negocio.
class ConfigTab extends StatefulWidget {
  const ConfigTab({super.key, required this.adminUid});

  final String adminUid;

  @override
  State<ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<ConfigTab> {
  final FirestoreService _firestore = FirestoreService();
  final LogoService _logoService = LogoService();
  final _formKey = GlobalKey<FormState>();

  final _businessName = TextEditingController();
  final _logoUrl = TextEditingController();
  final _stampImageUrl = TextEditingController();
  final _stampsGoal = TextEditingController();
  final _rewardDescription = TextEditingController();
  final _maxUsers = TextEditingController();
  final _contactInfo = TextEditingController();
  final _themeColor = TextEditingController();

  static const _presets = <String>[
    '#4F46E5',
    '#0EA5E9',
    '#10B981',
    '#F59E0B',
    '#EF4444',
    '#EC4899',
    '#8B5CF6',
    '#0F172A',
  ];

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _uploadingStamp = false;
  String? _loadError;
  String? _trialExpiryDate;
  String? _logoDataUri;
  String? _stampDataUri;
  String _checkinCode = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _businessName.dispose();
    _logoUrl.dispose();
    _stampImageUrl.dispose();
    _stampsGoal.dispose();
    _rewardDescription.dispose();
    _maxUsers.dispose();
    _contactInfo.dispose();
    _themeColor.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final config = await _firestore.getConfig();
      if (!mounted) return;
      setState(() {
        _businessName.text = config.businessName;
        final logo = config.logoUrl.trim();
        final isEmbedded = logo.startsWith('data:image/');
        _logoDataUri = isEmbedded ? logo : null;
        _logoUrl.text = isEmbedded ? '' : logo;
        final stamp = config.stampImage.trim();
        final stampEmbedded = stamp.startsWith('data:image/');
        _stampDataUri = stampEmbedded ? stamp : null;
        _stampImageUrl.text = stampEmbedded ? '' : stamp;
        _stampsGoal.text = '${config.stampsGoal}';
        _rewardDescription.text = config.rewardDescription;
        _maxUsers.text = '${config.maxUsers}';
        _contactInfo.text = config.contactInfo;
        _themeColor.text = config.themeColor;
        _trialExpiryDate = config.trialExpiryDate;
        _checkinCode = config.checkinCode;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error is Exception
            ? 'No se pudo cargar la configuración. Revisa tu conexión.'
            : 'No se pudo cargar la configuración.';
        _loading = false;
      });
    }
  }

  Color get _previewColor {
    final hex = _themeColor.text.replaceAll('#', '').trim();
    final value = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
    if (value == null) return const Color(0xFF4F46E5);
    return Color(0xFF000000 | value);
  }

  String _normalizedColor() {
    final hex = _themeColor.text.replaceAll('#', '').trim();
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
      return '#${hex.toUpperCase()}';
    }
    return ConfigModel.defaultThemeColor;
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _uploadLogo() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final dataUri = await _logoService.pickLogoAsDataUri();
      if (dataUri != null && mounted) {
        setState(() {
          _logoDataUri = dataUri;
          _logoUrl.clear();
        });
        _notify('Logo cargado. Guarda los cambios para aplicarlo.');
      }
    } catch (error) {
      _notify(
        error is StateError
            ? error.message
            : 'No se pudo cargar el logo. Inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadStampImage() async {
    if (_uploadingStamp) return;
    setState(() => _uploadingStamp = true);
    try {
      final dataUri = await _logoService.pickStampImageAsDataUri();
      if (dataUri != null && mounted) {
        setState(() {
          _stampDataUri = dataUri;
          _stampImageUrl.clear();
        });
        _notify('Imagen del sello cargada. Guarda los cambios para aplicarla.');
      }
    } catch (error) {
      _notify(
        error is StateError
            ? error.message
            : 'No se pudo cargar la imagen del sello. Inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _uploadingStamp = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
    });

    try {
      final code = _checkinCode.trim().isEmpty
          ? generateCheckinCode()
          : _checkinCode.trim().toUpperCase();

      final logo = _logoDataUri ?? _logoUrl.text.trim();
      final stampImage = _stampDataUri ?? _stampImageUrl.text.trim();
      if (logo.length + stampImage.length >
          AppConfig.maxConfigImageDataLength) {
        _notify(
          'Las imágenes son demasiado grandes para guardarlas juntas. '
          'Usa imágenes más pequeñas o URLs externas.',
        );
        return;
      }

      final config = ConfigModel(
        businessName: _businessName.text.trim(),
        logoUrl: logo,
        stampImage: stampImage,
        stampsGoal: int.parse(_stampsGoal.text.trim()),
        rewardDescription: _rewardDescription.text.trim(),
        themeColor: _normalizedColor(),
        maxUsers: int.parse(_maxUsers.text.trim()),
        checkinCode: code,
        contactInfo: _contactInfo.text.trim(),
        trialExpiryDate: _trialExpiryDate,
      );

      await _firestore.saveConfig(config);
      if (!mounted) return;
      setState(() {
        _checkinCode = code;
        _themeColor.text = config.themeColor;
      });
      _notify('Configuración guardada.');
    } catch (error) {
      _notify(
        error is AppFailure
            ? error.message
            : 'No se pudo guardar la configuración. Inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configuración',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Personaliza la tarjeta y el programa de fidelidad.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Guardando…' : 'Guardar'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Identidad del negocio',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _businessName,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del negocio',
                        prefixIcon: Icon(Icons.storefront_rounded),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Escribe el nombre del negocio.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerHighlight(
                          enabled: _logoDataUri != null,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: LogoImage(
                              source: _logoDataUri ?? _logoUrl.text.trim(),
                              fallback: const Icon(
                                Icons.image_outlined,
                                color: Colors.black38,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _logoUrl,
                            decoration: const InputDecoration(
                              labelText: 'URL del logo',
                              hintText: 'https://… o usa "Elegir imagen"',
                              prefixIcon: Icon(Icons.link_rounded),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {
                              _logoDataUri = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _uploading ? null : _uploadLogo,
                            icon: _uploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.image_rounded),
                            label: Text(
                              _uploading ? 'Cargando…' : 'Elegir imagen',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_logoDataUri != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Logo cargado y listo para guardar.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _logoDataUri = null;
                            }),
                            child: const Text('Quitar'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Color del tema',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ..._presets.map((hex) {
                          final selected =
                              _themeColor.text.toUpperCase() ==
                              hex.toUpperCase();
                          return InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => setState(() => _themeColor.text = hex),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _hexToColor(hex),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? Colors.black87
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        }),
                        SizedBox(
                          width: 130,
                          child: TextFormField(
                            controller: _themeColor,
                            decoration: const InputDecoration(
                              labelText: 'Hex',
                              hintText: '#4F46E5',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              final hex = (value ?? '')
                                  .replaceAll('#', '')
                                  .trim();
                              if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
                                return 'Formato #RRGGBB';
                              }
                              return null;
                            },
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _previewColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Programa de fidelidad',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stampsGoal,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Sellos para el premio',
                              prefixIcon: Icon(Icons.stars_rounded),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = int.tryParse((value ?? '').trim());
                              if (parsed == null || parsed < 1 || parsed > 50) {
                                return 'Entre 1 y 50';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _maxUsers,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Máximo de usuarios',
                              prefixIcon: Icon(Icons.group_rounded),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = int.tryParse((value ?? '').trim());
                              if (parsed == null || parsed < 1) {
                                return 'Mayor que 0';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rewardDescription,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Descripción del premio',
                        hintText: 'Ej: Un café gratis al completar la tarjeta.',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Describe el premio.'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Imagen del sello',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Aparece dentro de cada sello válido con una palomita '
                      'encima. Si la dejas vacía se usa el icono de check.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerHighlight(
                          enabled: _stampDataUri != null,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6FA),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: LogoImage(
                              source:
                                  _stampDataUri ?? _stampImageUrl.text.trim(),
                              fit: BoxFit.cover,
                              fallback: const Icon(
                                Icons.verified_rounded,
                                color: Colors.black38,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stampImageUrl,
                            decoration: const InputDecoration(
                              labelText: 'URL de la imagen del sello',
                              hintText: 'https://… o usa "Elegir imagen"',
                              prefixIcon: Icon(Icons.link_rounded),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {
                              _stampDataUri = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _uploadingStamp
                                ? null
                                : _uploadStampImage,
                            icon: _uploadingStamp
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.verified_rounded),
                            label: Text(
                              _uploadingStamp ? 'Cargando…' : 'Elegir imagen',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_stampDataUri != null ||
                        _stampImageUrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _stampDataUri != null
                                  ? 'Imagen del sello cargada y lista para guardar.'
                                  : 'Imagen del sello configurada por URL.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _stampDataUri = null;
                              _stampImageUrl.clear();
                            }),
                            child: const Text('Quitar'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Contacto y prueba',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _contactInfo,
                      maxLines: 2,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        labelText: 'Datos de contacto',
                        hintText:
                            'Ej: WhatsApp +34 600 000 000 · hola@negocio.com',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final trialExpiry = parseTrialExpiry(_trialExpiryDate);
                        final trialActive = trialIsActive(trialExpiry);
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    trialExpiry == null
                                        ? Icons.all_inclusive_rounded
                                        : trialActive
                                        ? Icons.verified_user_rounded
                                        : Icons.lock_clock_rounded,
                                    size: 18,
                                    color: trialExpiry == null
                                        ? Colors.black54
                                        : trialActive
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFB3261E),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Prueba del negocio',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                trialExpiry == null
                                    ? 'Sin fecha de expiración configurada.'
                                    : 'Expira: '
                                          '${formatTrialExpiry(trialExpiry)} '
                                          '(hora local)',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                              if (trialExpiry != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  trialRemainingLabel(trialExpiry),
                                  style: TextStyle(
                                    color: trialActive
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFB3261E),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              const Text(
                                'Solo el superadministrador puede modificar '
                                'la fecha desde la pestaña Plataforma.',
                                style: TextStyle(
                                  color: Colors.black45,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.qr_code_2_rounded, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _checkinCode.isEmpty
                                ? 'Código de check-in sin generar'
                                : 'Código de check-in: $_checkinCode',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => _checkinCode = generateCheckinCode(),
                          ),
                          child: const Text('Generar nuevo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final value = int.tryParse(hex.replaceAll('#', ''), radix: 16);
    if (value == null) return const Color(0xFF4F46E5);
    return Color(0xFF000000 | value);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      child: HoverLift(
        scale: 1.005,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
