import 'package:flutter/widgets.dart';

/// Breakpoints de la aplicación siguiendo la guía de Material 3 window sizes.
///
/// - `mobile`  : ancho < 600 dp   (teléfonos)
/// - `tablet`  : 600 dp ≤ ancho < 1024 dp  (tablets pequeñas / foldables)
/// - `desktop` : ancho ≥ 1024 dp  (tablets grandes, escritorio, web)
abstract final class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;

  /// `true` cuando el ancho de pantalla es de teléfono.
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  /// `true` cuando el ancho está entre 600 y 1024 dp.
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobile && width < tablet;
  }

  /// `true` cuando el ancho es >= 1024 dp (desktop / web).
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
}
