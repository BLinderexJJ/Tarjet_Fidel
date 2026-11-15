import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Tema base de la aplicación. El color principal puede venir de la
/// configuración del negocio (`config.themeColor`).
ThemeData buildAppTheme({Color seed = const Color(0xFF4F46E5)}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF5F6FA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Contenedor con el degradado de marca usado en las pantallas públicas.
///
/// El degradado y las luces se mueven lentamente para dar vida al fondo sin
/// distraer del formulario o de la tarjeta.
class BrandBackground extends StatefulWidget {
  const BrandBackground({
    super.key,
    required this.child,
    this.color = const Color(0xFF4F46E5),
  });

  final Widget child;
  final Color color;

  @override
  State<BrandBackground> createState() => _BrandBackgroundState();
}

class _BrandBackgroundState extends State<BrandBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (prefersReducedMotion(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(widget.color, Colors.black, 0.45) ?? widget.color;
    final light = Color.lerp(widget.color, Colors.white, 0.12) ?? widget.color;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final begin =
            Alignment.lerp(Alignment.topLeft, Alignment.topCenter, t) ??
            Alignment.topLeft;
        final end =
            Alignment.lerp(Alignment.bottomRight, Alignment.bottomCenter, t) ??
            Alignment.bottomRight;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [light, widget.color, dark],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: -110 + t * 24,
                top: -120 + t * 32,
                child: _GlowCircle(
                  size: 340,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              Positioned(
                left: -120 + t * 30,
                bottom: -140 + t * 22,
                child: _GlowCircle(
                  size: 300,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Positioned(
                right: 80 - t * 20,
                bottom: 90 + t * 18,
                child: _GlowCircle(
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
