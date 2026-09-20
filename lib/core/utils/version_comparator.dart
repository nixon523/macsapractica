/// Comparador semántico de versiones (Mayor.Menor.Parche).
/// Ignora sufijos como build numbers (+1, +2) y compara numéricamente cada segmento.
abstract final class VersionComparator {
  /// Retorna true si [remote] es estrictamente mayor que [current].
  /// Ejemplos:
  /// - isNewer('1.0.2', '1.0.1') => 	rue
  /// - isNewer('1.1.0', '1.0.9') => 	rue
  /// - isNewer('2.0.0', '1.9.9') => 	rue
  /// - isNewer('1.0.1', '1.0.1') => alse
  /// - isNewer('1.0.0', '1.0.1') => alse
  static bool isNewer(String remote, String current) {
    final r = _parse(remote);
    final c = _parse(current);

    for (var i = 0; i < 3; i++) {
      if (r[i] > c[i]) return true;
      if (r[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final clean = v.contains('+') ? v.split('+').first : v;
    final cleanHyphen = clean.contains('-') ? clean.split('-').first : clean;
    final parts = cleanHyphen.trim().split('.').map((p) => int.tryParse(p) ?? 0).toList();

    while (parts.length < 3) {
      parts.add(0);
    }
    return parts.take(3).toList();
  }
}
