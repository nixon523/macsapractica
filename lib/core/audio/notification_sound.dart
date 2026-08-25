import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Reproduce el sonido de notificación cuando llega un reporte de avería.
class NotificationSound {
  AudioPlayer? _player;

  /// Reproduce el "ding" de alerta. Los fallos (p. ej. autoplay bloqueado en
  /// web) se ignoran para no interrumpir la alerta visual.
  Future<void> play() async {
    final player = _player ??= AudioPlayer();
    try {
      await player.stop();
      await player.play(AssetSource('audio/notification.wav'));
    } catch (error) {
      debugPrint('NotificationSound: $error');
    }
  }
}
