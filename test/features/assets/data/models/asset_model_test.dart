import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/assets/data/models/asset_model.dart';
import 'package:macsapractica/features/assets/domain/entities/asset.dart';

void main() {
  group('AssetModel', () {
    const map = <String, dynamic>{
      'name': 'Bomba centrífuga',
      'brand': 'KSB',
      'model': 'Etanorm 80',
      'areaId': 'A1',
      'stationId': 'S1',
      'parentAssetId': 'A1-0000',
      'level': 'equipment',
      'ancestors': <String>['A1-0000'],
      'status': 'active',
      'transferredToId': null,
      'dynamicAttributes': <String, dynamic>{'potencia': '7.5 kW'},
      'imageData': 'data:image/jpeg;base64,QUJD',
    };

    test('fromFirestore construye el modelo correctamente', () {
      final model = AssetModel.fromFirestore(map, 'A1-0001');

      expect(model.id, 'A1-0001');
      expect(model.name, 'Bomba centrífuga');
      expect(model.areaId, 'A1');
      expect(model.level, AssetLevel.equipment);
      expect(model.status, AssetStatus.active);
      expect(model.ancestors, ['A1-0000']);
      expect(model.dynamicAttributes['potencia'], '7.5 kW');
      expect(model.imageData, 'data:image/jpeg;base64,QUJD');
    });

    test('toFirestore → fromFirestore es ida y vuelta (round-trip)', () {
      final original = AssetModel(
        id: 'A1-0001',
        name: 'Bomba centrífuga',
        brand: 'KSB',
        model: 'Etanorm 80',
        areaId: 'A1',
        stationId: 'S1',
        parentAssetId: 'A1-0000',
        level: AssetLevel.equipment,
        ancestors: const ['A1-0000'],
        status: AssetStatus.active,
        dynamicAttributes: const {'potencia': '7.5 kW'},
        imageData: 'data:image/jpeg;base64,QUJD',
      );

      final rebuilt =
          AssetModel.fromFirestore(original.toFirestore(), original.id);

      expect(rebuilt.id, original.id);
      expect(rebuilt.name, original.name);
      expect(rebuilt.brand, original.brand);
      expect(rebuilt.model, original.model);
      expect(rebuilt.areaId, original.areaId);
      expect(rebuilt.stationId, original.stationId);
      expect(rebuilt.parentAssetId, original.parentAssetId);
      expect(rebuilt.level, original.level);
      expect(rebuilt.ancestors, original.ancestors);
      expect(rebuilt.status, original.status);
      expect(rebuilt.dynamicAttributes, original.dynamicAttributes);
      expect(rebuilt.imageData, original.imageData);
    });

    test('usa valores por defecto cuando el mapa está incompleto', () {
      final model = AssetModel.fromFirestore(const {}, 'X1');

      expect(model.name, '');
      expect(model.level, AssetLevel.equipment);
      expect(model.status, AssetStatus.active);
      expect(model.ancestors, isEmpty);
    });

    test('toFirestore genera searchTerms sin acentos y sin duplicados', () {
      final model = AssetModel(
        id: 'A1-0001',
        name: 'Bomba centrífuga',
        brand: 'KSB',
        model: 'Etanorm 80',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: const [],
        status: AssetStatus.active,
        dynamicAttributes: const {},
      );

      final firestoreMap = model.toFirestore();

      expect(firestoreMap['searchTerms'], contains('bomba'));
      expect(firestoreMap['searchTerms'], contains('centrifuga'));
      expect(firestoreMap['searchTerms'], contains('a1'));
      expect(firestoreMap['searchTerms'], contains('etanorm'));
    });

    test('tokenize normaliza, acota a 10 tokens y deduplica', () {
      final tokens = Asset.tokenize('Motor A1-001 A1-001 Árbol de levas');

      expect(tokens, hasLength(6));
      expect(tokens, isNot(contains('Á')));
      expect(tokens, contains('arbol'));
    });

    // --- Tests del campo serial ---

    test('fromFirestore mapea el campo serial correctamente', () {
      final mapConSerial = {
        ...map,
        'serial': 'SN-2024-00142',
      };
      final model = AssetModel.fromFirestore(mapConSerial, 'A1-0001');
      expect(model.serial, equals('SN-2024-00142'));
    });

    test('fromFirestore deja serial como null si el campo no existe', () {
      final model = AssetModel.fromFirestore(map, 'A1-0001');
      expect(model.serial, isNull);
    });

    test('toFirestore NO incluye el campo serial cuando es null', () {
      final model = AssetModel(
        id: 'A1-0001',
        name: 'Bomba',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: const [],
        status: AssetStatus.active,
        dynamicAttributes: const {},
        serial: null,
      );
      final firestoreMap = model.toFirestore();
      expect(firestoreMap.containsKey('serial'), isFalse);
    });

    test('toFirestore NO incluye el campo serial cuando es cadena vacía', () {
      final model = AssetModel(
        id: 'A1-0001',
        name: 'Bomba',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: const [],
        status: AssetStatus.active,
        dynamicAttributes: const {},
        serial: '',
      );
      final firestoreMap = model.toFirestore();
      expect(firestoreMap.containsKey('serial'), isFalse);
    });

    test('toFirestore SÍ incluye serial cuando tiene valor', () {
      final model = AssetModel(
        id: 'A1-0001',
        name: 'Bomba',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: const [],
        status: AssetStatus.active,
        dynamicAttributes: const {},
        serial: 'SN-2024-00142',
      );
      final firestoreMap = model.toFirestore();
      expect(firestoreMap['serial'], equals('SN-2024-00142'));
    });

    test('searchTerms incluye tokens del serial', () {
      final model = AssetModel(
        id: 'A1-0001',
        name: 'Bomba',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: const [],
        status: AssetStatus.active,
        dynamicAttributes: const {},
        serial: 'SN-2024-00142',
      );
      final firestoreMap = model.toFirestore();
      final searchTerms = firestoreMap['searchTerms'] as List<String>;
      expect(searchTerms, contains('sn'));
      expect(searchTerms, contains('2024'));
      expect(searchTerms, contains('00142'));
    });

    test('round-trip conserva el serial correctamente', () {
      final original = AssetModel(
        id: 'A1-0001',
        name: 'Bomba',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: const [],
        status: AssetStatus.active,
        dynamicAttributes: const {},
        serial: 'SN-2024-00999',
      );
      final rebuilt = AssetModel.fromFirestore(original.toFirestore(), original.id);
      expect(rebuilt.serial, equals('SN-2024-00999'));
    });
  });
}
