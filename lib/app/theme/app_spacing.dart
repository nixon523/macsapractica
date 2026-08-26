/// Escala de espaciado consistente para toda la aplicación.
///
/// Basada en una escala de 4 pt (Material Design 3). Úsala en lugar de valores
/// literales para padding, márgenes y espacios entre widgets.
abstract final class AppSpacing {
  /// 4 pt — espacio mínimo entre elementos muy relacionados.
  static const double xs = 4;

  /// 8 pt — espacio pequeño (entre íconos y texto, chips internos).
  static const double sm = 8;

  /// 12 pt — espacio compacto (entre campos de formulario densos).
  static const double md = 12;

  /// 16 pt — espacio estándar (padding de tarjetas y pantallas).
  static const double lg = 16;

  /// 24 pt — espacio amplio (secciones distintas dentro de una vista).
  static const double xl = 24;

  /// 32 pt — separación entre bloques mayores.
  static const double xxl = 32;

  /// 48 pt — para espaciados hero / vacíos grandes.
  static const double xxxl = 48;
}
