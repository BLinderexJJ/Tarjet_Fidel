import 'package:flutter/widgets.dart';

/// Indica si el sistema pidió reducir el movimiento (accesibilidad).
///
/// Cuando es `true`, las animaciones decorativas se desactivan o se sustituyen
/// por su estado final para evitar mareos y ahorrar batería.
bool prefersReducedMotion(BuildContext context) {
  return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
