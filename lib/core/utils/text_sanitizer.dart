/// Utilidad centralizada para sanitizar y limpiar textos y descripciones,
/// eliminando mojibake, secuencias UTF-8 mal decodificadas y artefactos de formato.
class TextSanitizer {
  TextSanitizer._();

  /// Repara secuencias UTF-8 mal decodificadas como Windows-1252 / Latin1
  /// (por ejemplo `Ã¡` -> `á`, `Ã©` -> `é`, `Ã\x81` -> `Á`, etc.).
  static String fixEncoding(String? raw) {
    if (raw == null || raw.isEmpty) return raw ?? '';
    return raw
        .replaceAll('\u00C3\u00A1', 'á') // Ã¡
        .replaceAll('\u00C3\u00A9', 'é') // Ã©
        .replaceAll('\u00C3\u00AD', 'í') // Ã­
        .replaceAll('\u00C3\u00B3', 'ó') // Ã³
        .replaceAll('\u00C3\u00BA', 'ú') // Ãº
        .replaceAll('\u00C3\u00B1', 'ñ') // Ã±
        .replaceAll('\u00C3\u00BC', 'ü') // Ã¼
        .replaceAll('\u00C3\u0081', 'Á') // Ã\x81
        .replaceAll('\u00C3\u0089', 'É')
        .replaceAll('\u00C3\u2030', 'É') // Ã‰
        .replaceAll('\u00C3\u008D', 'Í')
        .replaceAll('\u00C3\u0093', 'Ó')
        .replaceAll('\u00C3\u201C', 'Ó') // Ã“
        .replaceAll('\u00C3\u009A', 'Ú')
        .replaceAll('\u00C3\u0161', 'Ú') // Ãš
        .replaceAll('\u00C3\u0091', 'Ñ')
        .replaceAll('\u00C3\u2018', 'Ñ') // Ã‘
        .replaceAll('\u00C2\u00BF', '¿')
        .replaceAll('\u00C2\u00A1', '¡')
        .replaceAll('\u00C2\u00B0', '°')
        .replaceAll('\u00C2\u00B7', '·');
  }

  /// Limpia una descripción o texto general eliminando caracteres no estándar,
  /// balas unicode problemáticas y secuencias mojibake (e.g. `â€¢`, `â\x80¢`).
  static String cleanDescription(String? raw) {
    if (raw == null || raw.isEmpty) return raw ?? '';
    var cleaned = fixEncoding(raw);

    // 1. Limpieza exhaustiva de mojibake y secuencias de bytes mal interpretadas
    cleaned = cleaned
        .replaceAll('\u00E2\u20AC\u00A2', '- ') // â€¢
        .replaceAll('\u00E2\u0080\u00A2', '- ') // â\x80¢
        .replaceAll('â€¢', '- ')
        .replaceAll('â\x80¢', '- ')
        .replaceAll('\u00E2\u20AC\u201D', ' - ') // â€” (em-dash)
        .replaceAll('\u00E2\u20AC\u2013', ' - ') // â€“ (en-dash)
        .replaceAll('\u00E2\u0080\u0094', ' - ')
        .replaceAll('\u00E2\u0080\u0093', ' - ')
        .replaceAll('â€”', ' - ')
        .replaceAll('â€“', ' - ')
        .replaceAll('â€', '')
        .replaceAll('\u00E2\u0080', '')
        .replaceAll('\u0080', '')
        .replaceAll('•', '- ')
        .replaceAll('—', ' - ')
        .replaceAll('–', ' - ');

    // 2. Normalizar asteriscos como viñetas al inicio de línea o tras saltos de línea
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[*•]\s*', multiLine: true), '- ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+\*\s+'), '\n- ');

    // 3. Normalizar formato de ítems con corchetes " - [ID - Nombre]: Tarea" -> "- Nombre (ID): Tarea"
    final itemWithBracketPattern = RegExp(
      r'^\s*[-*•]\s*\[\s*([A-Za-z0-9\-_]+)\s*-\s*([^\]]+)\]\s*:\s*(.*)$',
      multiLine: true,
    );
    cleaned = cleaned.replaceAllMapped(itemWithBracketPattern, (match) {
      final id = match.group(1)?.trim() ?? '';
      final name = match.group(2)?.trim() ?? '';
      final task = match.group(3)?.trim() ?? '';
      return '- $name ($id): $task';
    });

    // 4. Normalizar corchetes sueltos "[ID - Nombre]" -> "Nombre (ID)"
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[\s*([A-Za-z0-9\-_]+)\s*-\s*([^\]]+)\]'),
      (match) {
        final id = match.group(1)?.trim() ?? '';
        final name = match.group(2)?.trim() ?? '';
        return '$name ($id)';
      },
    );

    // 5. Limpiar corchetes que envuelven títulos principales "[Mantenimiento Preventivo...]"
    cleaned = cleaned.replaceAll(
      RegExp(r'^\[(Mantenimiento Preventivo[^\]]+)\]', multiLine: true),
      r'$1',
    );

    // 6. Normalizar espacios redundantes y viñetas
    cleaned = cleaned.replaceAll(RegExp(r'^\s*-\s+', multiLine: true), '- ');
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

    return cleaned.trim();
  }
}
