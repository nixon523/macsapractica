import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/utils/version_comparator.dart';

void main() {
  group('VersionComparator', () {
    test('detecta versión patch superior', () {
      expect(VersionComparator.isNewer('1.0.2', '1.0.1'), isTrue);
    });

    test('detecta versión minor superior', () {
      expect(VersionComparator.isNewer('1.1.0', '1.0.9'), isTrue);
    });

    test('detecta versión major superior', () {
      expect(VersionComparator.isNewer('2.0.0', '1.9.9'), isTrue);
    });

    test('retorna false si la versión es idéntica', () {
      expect(VersionComparator.isNewer('1.0.1', '1.0.1'), isFalse);
    });

    test('retorna false si la versión remota es inferior', () {
      expect(VersionComparator.isNewer('1.0.0', '1.0.1'), isFalse);
    });

    test('ignora sufijos de build number (+1, +2)', () {
      expect(VersionComparator.isNewer('1.0.2+3', '1.0.1+1'), isTrue);
      expect(VersionComparator.isNewer('1.0.1+5', '1.0.1+2'), isFalse);
    });
  });
}
