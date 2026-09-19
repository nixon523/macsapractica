import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/utils/text_sanitizer.dart';

void main() {
  group('TextSanitizer', () {
    test('cleans standard mojibake bullets and dashes', () {
      const raw = 'â€¢ A1-001-01 - Bomba: Reparación\nâ€¢ A1-002-02 - Motor â€” cambio';
      final cleaned = TextSanitizer.cleanDescription(raw);
      expect(cleaned, contains('- A1-001-01 - Bomba: Reparación'));
      expect(cleaned, contains('- A1-002-02 - Motor - cambio'));
      expect(cleaned.contains('â'), isFalse);
    });

    test('cleans Latin-1 decoded byte sequence mojibake', () {
      final raw = '\u00E2\u0080\u00A2 A1-001 - Rótula: Ajuste';
      final cleaned = TextSanitizer.cleanDescription(raw);
      expect(cleaned, equals('- A1-001 - Rótula: Ajuste'));
      expect(cleaned.contains('\u0080'), isFalse);
    });

    test('normalizes bracketed IDs and names', () {
      const raw = ' - [A1-001-01 - Rodamiento]: Mantenimiento preventivo';
      final cleaned = TextSanitizer.cleanDescription(raw);
      expect(cleaned, equals('- Rodamiento (A1-001-01): Mantenimiento preventivo'));
    });

    test('handles null and empty gracefully', () {
      expect(TextSanitizer.cleanDescription(null), equals(''));
      expect(TextSanitizer.cleanDescription(''), equals(''));
    });
  });
}
