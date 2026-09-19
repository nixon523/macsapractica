import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

/// Elemento de la cola de notificaciones in-app.
class NotificationItem {
  const NotificationItem({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.soundCallback,
  });

  final IconData icon;
  final Color iconColor;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Callback opcional para reproducir sonido de alerta.
  final VoidCallback? soundCallback;
}

/// Cola FIFO de notificaciones tipo SnackBar. Evita que `clearSnackBars()`
/// sobrescriba notificaciones anteriores al presentar una a la vez con
/// un mínimo de 4 segundos de separación.
///
/// Si hay más de 3 pendientes, muestra un SnackBar resumen.
class NotificationQueue {
  NotificationQueue();

  final Queue<NotificationItem> _queue = Queue<NotificationItem>();
  bool _isShowing = false;
  Timer? _debounce;

  /// Agrega una notificación a la cola. Si no se está mostrando ninguna,
  /// la presenta inmediatamente.
  void enqueue(BuildContext context, NotificationItem item) {
    _queue.add(item);
    if (!_isShowing) {
      _showNext(context);
    }
  }

  void _showNext(BuildContext context) {
    if (_queue.isEmpty) {
      _isShowing = false;
      return;
    }
    _isShowing = true;

    // Si hay demasiadas pendientes, mostramos resumen
    if (_queue.length > 3) {
      final count = _queue.length;
      _queue.clear();
      _showSnackBar(
        context,
        NotificationItem(
          icon: Icons.notifications_active,
          iconColor: Colors.orangeAccent,
          message: '$count nuevas alertas pendientes.',
        ),
      );
      return;
    }

    final item = _queue.removeFirst();
    item.soundCallback?.call();
    _showSnackBar(context, item);
  }

  void _showSnackBar(BuildContext context, NotificationItem item) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      _isShowing = false;
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dismissDirection: DismissDirection.horizontal,
        content: Row(
          children: [
            Icon(item.icon, color: item.iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: item.actionLabel != null
            ? SnackBarAction(
                label: item.actionLabel!,
                textColor: item.iconColor,
                onPressed: () {
                  item.onAction?.call();
                },
              )
            : null,
      ),
    );

    // Esperar a que termine el SnackBar antes de mostrar el siguiente
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 4500), () {
      _showNext(context);
    });
  }

  /// Limpia la cola y detiene cualquier temporizador activo.
  void clear() {
    _queue.clear();
    _debounce?.cancel();
    _isShowing = false;
  }
}
