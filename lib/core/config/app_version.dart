import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Versión actual de la aplicación (consultada en tiempo de ejecución desde Android / Web).
abstract final class AppVersion {
  static String _current = '1.0.3';
  static String _build = '4';

  static String get current => _current;
  static String get build => _build;
  static String get full => '$_current+$_build';

  /// Inicializa la versión real en tiempo de ejecución desde los metadatos del paquete instalado.
  static Future<void> initialize() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        _current = info.version;
        _build = info.buildNumber;
      }
    } catch (_) {
      // Mantiene el valor base si ocurre un fallo o en pruebas sin canal de plataforma.
    }
  }

  /// Método para pruebas unitarias.
  @visibleForTesting
  static void setVersionForTesting({required String version, String build = '1'}) {
    _current = version;
    _build = build;
  }
}

