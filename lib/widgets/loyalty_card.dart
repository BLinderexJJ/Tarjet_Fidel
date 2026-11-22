import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/config_model.dart';
import '../models/user_model.dart';
import '../utils/motion.dart';
import 'logo_image.dart';

/// Tarjeta de fidelidad con progreso animado de sellos.
class LoyaltyCard extends StatelessWidget {
  const LoyaltyCard({
    super.key,
    required this.user,
    required this.config,
    this.animateStamps = false,
  });

  final UserModel user;
  final ConfigModel config;
  final bool animateStamps;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = prefersReducedMotion(context);
    final goal = config.stampsGoal.clamp(1, 100);
    final stamps = user.currentStamps.clamp(0, goal);
    final progress = stamps / goal;
    final rewardReady = user.isRewardReadyFor(goal);
    final base = config.color;
    final dark = Color.lerp(base, Colors.black, 0.35) ?? base;

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, dark],
        ),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -70,
            child: _DecorativeCircle(size: 220, opacity: 0.10),
          ),
          Positioned(
            right: 40,
            bottom: -90,
            child: _DecorativeCircle(size: 180, opacity: 0.08),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Logo(url: config.logoUrl),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.businessName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tarjeta de fidelidad',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (rewardReady)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              size: 16,
                              color: Color(0xFF4A3200),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Premio listo',
                              style: TextStyle(
                                color: Color(0xFF4A3200),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Hola, ${user.name}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$stamps',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 6),
                      child: Text(
                        '/ $goal sellos',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.20),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 10.0;
                    const wantedSize = 52.0;
                    final available = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : wantedSize * 5;
                    final perRow =
                        ((available + spacing) / (wantedSize + spacing))
                            .floor()
                            .clamp(1, goal)
                            .toInt();
                    final size = ((available - spacing * (perRow - 1)) / perRow)
                        .clamp(32.0, wantedSize)
                        .toDouble();

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: List.generate(goal, (index) {
                        final filled = index < stamps;
                        final isLastFilled = filled && index == stamps - 1;
                        Widget stamp = _Stamp(
                          filled: filled,
                          index: index + 1,
                          size: size,
                          imageSource: config.stampImage,
                          accent: dark,
                        );
                        if (animateStamps && isLastFilled && !reduceMotion) {
                          stamp = stamp
                              .animate()
                              .scale(
                                begin: const Offset(0.3, 0.3),
                                end: const Offset(1, 1),
                                duration: 450.ms,
                                curve: Curves.elasticOut,
                              )
                              .fadeIn(duration: 200.ms);
                        }
                        return stamp;
                      }),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.card_giftcard_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          config.rewardDescription,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (reduceMotion) return card;
    return card.animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: LogoImage(
        source: url,
        fallback: const Icon(
          Icons.storefront_rounded,
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.filled,
    required this.index,
    required this.size,
    required this.imageSource,
    required this.accent,
  });

  final bool filled;
  final int index;
  final double size;
  final String imageSource;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = prefersReducedMotion(context);
    final hasImage = filled && imageSource.trim().isNotEmpty;
    final checkColor = Color.lerp(accent, Colors.black, 0.45) ?? accent;
    final badgeSize = size * 0.42;

    return Semantics(
      key: Key('stamp_$index'),
      label: filled ? 'Sello $index válido' : 'Sello $index pendiente',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: filled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
                width: filled ? 2.5 : 1.5,
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: ClipOval(
              child: hasImage
                  ? LogoImage(
                      source: imageSource,
                      fit: BoxFit.cover,
                      fallback: Icon(
                        Icons.verified_rounded,
                        size: size * 0.5,
                        color: checkColor,
                      ),
                    )
                  : Center(
                      child: filled
                          ? Icon(
                              Icons.check_rounded,
                              size: size * 0.56,
                              color: checkColor,
                            )
                          : Text(
                              '$index',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: size * 0.36,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
            ),
          ),
          if (hasImage)
            Positioned(
              right: -size * 0.05,
              top: -size * 0.05,
              child: Container(
                key: Key('stamp_${index}_check'),
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: badgeSize * 0.72,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
