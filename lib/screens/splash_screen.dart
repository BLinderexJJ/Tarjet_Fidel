import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_animations.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
    this.businessName,
    this.color = const Color(0xFF4F46E5),
  });

  final String? businessName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandBackground(
        color: color,
        child: Center(
          child: Reveal(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Pulse(
                  maxScale: 1.06,
                  duration: const Duration(milliseconds: 1600),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 44,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                ShimmerHighlight(
                  color: Colors.white.withValues(alpha: 0.55),
                  child: Text(
                    businessName?.trim().isNotEmpty == true
                        ? businessName!
                        : 'Tarjet Fidel',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tarjetas de fidelidad digitales',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
