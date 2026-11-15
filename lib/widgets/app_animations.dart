import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Entrada suave: fade + deslizamiento vertical.
///
/// Se usa para que cada tarjeta, sección o fila aparezca con vida al montarse.
/// El efecto se reproduce una sola vez y no reinicia en cada rebuild.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.slide = 0.06,
    this.enabled = true,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Fracción de la altura del widget que se desplaza al entrar.
  final double slide;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return child
        .animate()
        .fadeIn(duration: duration, delay: delay, curve: Curves.easeOutCubic)
        .slideY(
          begin: slide,
          end: 0,
          duration: duration,
          delay: delay,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Eleva ligeramente el contenido al pasar el ratón por encima.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.scale = 1.015,
    this.lift = 0.006,
    this.cursor = SystemMouseCursors.basic,
  });

  final Widget child;
  final double scale;

  /// Fracción de la altura que sube el widget.
  final double lift;
  final MouseCursor cursor;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? widget.scale : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: _hovered ? Offset(0, -widget.lift) : Offset.zero,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Pulso continuo y suave para iconos, insignias o avisos importantes.
class Pulse extends StatefulWidget {
  const Pulse({
    super.key,
    required this.child,
    this.minScale = 1,
    this.maxScale = 1.045,
    this.duration = const Duration(milliseconds: 1400),
    this.enabled = true,
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;
  final bool enabled;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant Pulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = widget.minScale + (widget.maxScale - widget.minScale) * t;
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

/// Brillo que recorre el contenido, útil para códigos y elementos destacados.
class ShimmerHighlight extends StatelessWidget {
  const ShimmerHighlight({
    super.key,
    required this.child,
    this.enabled = true,
    this.color = const Color(0x66FFFFFF),
    this.duration = const Duration(milliseconds: 2200),
  });

  final Widget child;
  final bool enabled;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return child
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: duration, color: color, curve: Curves.easeInOut);
  }
}

/// Como [IndexedStack], pero con un fundido suave al cambiar de pestaña.
///
/// Mantiene vivas todas las páginas (y sus streams) para no perder estado.
class AnimatedIndexedStack extends StatelessWidget {
  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 260),
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(children.length, (i) {
        final active = i == index;
        return IgnorePointer(
          ignoring: !active,
          child: TickerMode(
            enabled: active,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: children[i],
            ),
          ),
        );
      }),
    );
  }
}

/// Aparición escalonada para listas: cada elemento entra un poco después.
class StaggeredReveal extends StatelessWidget {
  const StaggeredReveal({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 55),
    this.maxDelay = const Duration(milliseconds: 420),
    this.enabled = true,
  });

  final int index;
  final Widget child;
  final Duration step;
  final Duration maxDelay;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final delay = step * index;
    return Reveal(
      delay: delay > maxDelay ? maxDelay : delay,
      enabled: enabled,
      child: child,
    );
  }
}
