import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/assets/data/models/area_model.dart';

void main() {
  group('AreaModel', () {
    const map = <String, dynamic>{
      'id': 'A3',
      'name': 'Planta de Procesamiento',
      'costCenter': 'CC-03',
      'assetCounter': 2,
    };

    test('fromFirestore construye el modelo correctamente', () {
      final model = AreaModel.fromFirestore(map, 'A3');

      expect(model.id, 'A3');
      expect(model.name, 'Planta de Procesamiento');
      expect(model.costCenter, 'CC-03');
      expect(model.assetCounter, 2);
    });

    test('toFirestore → fromFirestore es ida y vuelta (round-trip)', () {
      const original = AreaModel(
        id: 'A1',
        name: 'Empacadora',
        costCenter: 'CC-01',
        assetCounter: 5,
      );

      final rebuilt =
          AreaModel.fromFirestore(original.toFirestore(), original.id);

      expect(rebuilt.id, original.id);
      expect(rebuilt.name, original.name);
      expect(rebuilt.costCenter, original.costCenter);
      expect(rebuilt.assetCounter, original.assetCounter);
    });

    test('usa valores por defecto cuando el mapa está incompleto', () {
      final model = AreaModel.fromFirestore(const {}, 'A9');

      expect(model.name, '');
      expect(model.costCenter, '');
      expect(model.assetCounter, 0);
    });
  });
}
