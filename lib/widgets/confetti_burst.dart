import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Explosión de confeti que se reproduce cuando cambia [trigger].
///
/// Colócalo como última capa de un [Stack] con `Positioned.fill`. No bloquea
/// toques (`IgnorePointer`) y se apaga solo al terminar.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.trigger = 0,
    this.duration = const Duration(milliseconds: 1700),
    this.particleCount = 70,
  });

  /// Incrementa este valor para volver a lanzar el confeti.
  final int trigger;
  final Duration duration;
  final int particleCount;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  List<_ConfettiParticle> _particles = const [];
  int _seed = 0;

  @override
  void initState() {
    super.initState();
    if (widget.trigger > 0) _play();
  }

  @override
  void didUpdateWidget(covariant ConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _play();
    }
  }

  void _play() {
    _seed += 1;
    _particles = _buildParticles(widget.particleCount, _seed);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          if (progress <= 0 || progress >= 1) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            painter: _ConfettiPainter(
              progress: progress,
              particles: _particles,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _ConfettiParticle {
  const _ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double angle;
  final double speed;
  final double spin;
  final double size;
  final Color color;
}

const _palette = <Color>[
  Color(0xFFFFC94D),
  Color(0xFFFF8A65),
  Color(0xFF4ADE80),
  Color(0xFF60A5FA),
  Color(0xFFC084FC),
  Color(0xFFF472B6),
  Color(0xFFFFFFFF),
];

List<_ConfettiParticle> _buildParticles(int count, int seed) {
  final random = math.Random(seed * 7919 + 17);
  return List.generate(count, (index) {
    // Ángulo hacia arriba: entre -150° y -30°.
    final angle = -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 0.95;
    return _ConfettiParticle(
      angle: angle,
      speed: 0.35 + random.nextDouble() * 0.75,
      spin: (random.nextDouble() - 0.5) * 3.2,
      size: 5 + random.nextDouble() * 7,
      color: _palette[index % _palette.length],
    );
  });
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.particles});

  final double progress;
  final List<_ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final opacity = progress < 0.68
        ? 1.0
        : (1 - (progress - 0.68) / 0.32).clamp(0.0, 1.0);

    for (final particle in particles) {
      final x =
          size.width *
          (0.5 + math.cos(particle.angle) * particle.speed * progress);
      final y =
          size.height *
          (0.52 +
              math.sin(particle.angle) * particle.speed * progress +
              0.9 * progress * progress);

      paint.color = particle.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.spin * progress * math.pi * 2);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: particle.size,
        height: particle.size * 0.58,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles != particles;
  }
}

/// Lanza confeti cuando [value] aumenta.
///
/// Ideal para celebrar sellos nuevos, aprobaciones o canjes sin llenar las
/// pantallas de lógica de animación.
class CelebrationOnChange extends StatefulWidget {
  const CelebrationOnChange({
    super.key,
    required this.value,
    required this.child,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 1700),
  });

  final int value;
  final Widget child;
  final bool enabled;
  final Duration duration;

  @override
  State<CelebrationOnChange> createState() => _CelebrationOnChangeState();
}

class _CelebrationOnChangeState extends State<CelebrationOnChange> {
  int _trigger = 0;

  @override
  void didUpdateWidget(covariant CelebrationOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && widget.value > oldWidget.value) {
      _trigger += 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: ConfettiBurst(trigger: _trigger, duration: widget.duration),
        ),
      ],
    );
  }
}
