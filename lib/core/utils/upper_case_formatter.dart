import 'package:flutter/services.dart';

/// Convierte automáticamente toda la entrada de texto a MAYÚSCULAS.
///
/// Se utiliza como `inputFormatters: [UpperCaseTextFormatter()]` en
/// campos de nombre de usuario y contraseña para estandarizar la
/// entrada y evitar errores por diferencia de case.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: newValue.composing,
    );
  }
}
