// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Actualiza el título, la descripción y el color del navegador con los datos
/// del negocio para que la pestaña y la barra del móvil se sientan propias.
void applyWebMeta({required String title, required String themeColor}) {
  final safeTitle = title.trim().isEmpty ? 'Tarjet Fidel' : title.trim();
  final safeColor = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(themeColor.trim())
      ? themeColor.trim()
      : '#4F46E5';

  html.document.title = safeTitle;

  final theme = html.document.querySelector('meta[name="theme-color"]');
  theme?.setAttribute('content', safeColor);

  final appleTitle = html.document.querySelector(
    'meta[name="apple-mobile-web-app-title"]',
  );
  appleTitle?.setAttribute('content', safeTitle);

  final description = html.document.querySelector('meta[name="description"]');
  description?.setAttribute(
    'content',
    '$safeTitle: tarjetas de fidelidad digitales para tu negocio.',
  );
}
