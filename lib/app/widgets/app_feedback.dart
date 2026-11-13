import 'package:flutter/material.dart';

import '../theme/app_radius.dart';

/// Servicio centralizado de retroalimentación visual (SnackBars / Alertas flotantes).
///
/// Estandariza la paleta corporativa de Grupo Macsa:
/// - Éxito: Azul Institucional Macsa (`#0055A5`).
/// - Error: Rojo Alerta (`#DC2626`).
/// - Advertencia: Ámbar (`#D97706`).
/// - Información: Azul Corporativo (`#0055A5`).
class AppFeedback {
  AppFeedback._();

  static const Color macsaBlue = Color(0xFF0055A5);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color warningAmber = Color(0xFFD97706);

  /// Muestra una notificación flotante de éxito con el azul institucional Macsa.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: macsaBlue,
      icon: Icons.check_circle_outline,
      duration: duration,
      action: action,
    );
  }

  /// Muestra una notificación flotante de error.
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: dangerRed,
      icon: Icons.error_outline,
      duration: duration,
      action: action,
    );
  }

  /// Muestra una notificación flotante de advertencia preventiva.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: warningAmber,
      icon: Icons.warning_amber_rounded,
      duration: duration,
      action: action,
    );
  }

  /// Muestra una notificación flotante informativa.
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: macsaBlue,
      icon: Icons.info_outline,
      duration: duration,
      action: action,
    );
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    required Duration duration,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
        backgroundColor: backgroundColor,
        action: action,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
