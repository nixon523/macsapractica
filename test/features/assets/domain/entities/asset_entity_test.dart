import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/assets/domain/entities/asset.dart';

void main() {
  group('Asset.tokenize()', () {
    test('normaliza minúsculas y elimina acentos', () {
      final tokens = Asset.tokenize('Centrífuga');
      expect(tokens, contains('centrifuga'));
      expect(tokens, isNot(contains('centrífuga')));
    });

    test('divide por espacios', () {
      final tokens = Asset.tokenize('Bomba Principal');
      expect(tokens, containsAll(['bomba', 'principal']));
    });

    test('divide por guiones', () {
      final tokens = Asset.tokenize('A3-002-01');
      expect(tokens, containsAll(['a3', '002', '01']));
    });

    test('divide por puntos y barras', () {
      final tokens = Asset.tokenize('Motor/Reductor 5.5kw');
      expect(tokens, containsAll(['motor', 'reductor', '5', '5kw']));
    });

    test('elimina tokens vacíos', () {
      final tokens = Asset.tokenize('  Bomba  ');
      expect(tokens, equals(['bomba']));
      expect(tokens.every((t) => t.isNotEmpty), isTrue);
    });

    test('cadena vacía retorna lista vacía', () {
      expect(Asset.tokenize(''), isEmpty);
    });

    test('cadena solo de espacios retorna lista vacía', () {
      expect(Asset.tokenize('   '), isEmpty);
    });

    test('no supera 10 tokens', () {
      final longText = 'a b c d e f g h i j k l m n o';
      final tokens = Asset.tokenize(longText);
      expect(tokens.length, lessThanOrEqualTo(10));
    });

    test('no produce duplicados', () {
      final tokens = Asset.tokenize('bomba bomba motor bomba');
      final unique = tokens.toSet();
      expect(tokens.length, equals(unique.length));
    });

    test('normaliza ñ → n y ü → u', () {
      final tokens = Asset.tokenize('Ñoño müelle');
      expect(tokens, containsAll(['nono', 'muelle']));
    });
  });

  group('Asset.isActive', () {
    test('retorna true para status active', () {
      const asset = Asset(
        id: 'A1-001',
        name: 'Test',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: [],
        status: AssetStatus.active,
        dynamicAttributes: {},
      );
      expect(asset.isActive, isTrue);
    });

    test('retorna false para status inactive', () {
      const asset = Asset(
        id: 'A1-001',
        name: 'Test',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: [],
        status: AssetStatus.inactive,
        dynamicAttributes: {},
      );
      expect(asset.isActive, isFalse);
    });

    test('retorna false para status transferredDeactivated', () {
      const asset = Asset(
        id: 'A1-001',
        name: 'Test',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: [],
        status: AssetStatus.transferredDeactivated,
        dynamicAttributes: {},
      );
      expect(asset.isActive, isFalse);
    });
  });

  group('Asset serial', () {
    test('serial puede ser null (opcional)', () {
      const asset = Asset(
        id: 'A1-001',
        name: 'Bomba',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: [],
        status: AssetStatus.active,
        dynamicAttributes: {},
      );
      expect(asset.serial, isNull);
    });

    test('serial se almacena correctamente', () {
      const asset = Asset(
        id: 'A1-001',
        name: 'Bomba',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: [],
        status: AssetStatus.active,
        dynamicAttributes: {},
        serial: 'SN-2024-00142',
      );
      expect(asset.serial, equals('SN-2024-00142'));
    });

    test('copyWith hereda el serial (inmutable)', () {
      const asset = Asset(
        id: 'A1-001',
        name: 'Bomba',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: [],
        status: AssetStatus.active,
        dynamicAttributes: {},
        serial: 'SN-2024-00142',
      );
      final copied = asset.copyWith(name: 'Bomba actualizada');
      expect(copied.serial, equals('SN-2024-00142'));
    });

    test('dos activos con mismo serial son distintos si tienen distinto ID', () {
      const a1 = Asset(
        id: 'A1-001',
        name: 'Bomba A',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: [],
        status: AssetStatus.active,
        dynamicAttributes: {},
        serial: 'SN-001',
      );
      const a2 = Asset(
        id: 'A2-001',
        name: 'Bomba B',
        areaId: 'A2',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: [],
        status: AssetStatus.active,
        dynamicAttributes: {},
        serial: 'SN-001',
      );
      expect(a1, isNot(equals(a2)));
    });
  });
}
