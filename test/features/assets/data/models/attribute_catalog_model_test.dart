import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/assets/data/models/asset_attribute_definition_model.dart';
import 'package:macsapractica/features/assets/data/models/brand_model.dart';
import 'package:macsapractica/features/assets/data/models/unit_of_measure_model.dart';

void main() {
  group('BrandModel', () {
    test('deserializa correctamente desde JSON (camelCase y PascalCase)', () {
      final jsonCamel = {
        'id': 1,
        'name': 'Siemens',
        'description': 'Motores y PLCs',
        'isActive': true,
        'totalAssetsAssociated': 5,
      };

      final model = BrandModel.fromJson(jsonCamel);
      expect(model.id, 1);
      expect(model.name, 'Siemens');
      expect(model.description, 'Motores y PLCs');
      expect(model.isActive, true);
      expect(model.totalAssetsAssociated, 5);

      final jsonPascal = {
        'MarcaId': '2',
        'Nombre': 'ABB',
        'Descripcion': 'Variadores',
        'Activo': 1,
        'TotalActivosAsociados': 3,
      };

      final modelPascal = BrandModel.fromJson(jsonPascal);
      expect(modelPascal.id, 2);
      expect(modelPascal.name, 'ABB');
      expect(modelPascal.description, 'Variadores');
      expect(modelPascal.isActive, true);
      expect(modelPascal.totalAssetsAssociated, 3);
    });

    test('serializa a JSON correctamente', () {
      const model = BrandModel(
        id: 7,
        name: 'Danfoss',
        description: 'Válvulas y compresores',
        isActive: true,
      );

      final json = model.toJson();
      expect(json['id'], 7);
      expect(json['name'], 'Danfoss');
      expect(json['description'], 'Válvulas y compresores');
      expect(json['isActive'], true);
    });
  });

  group('UnitOfMeasureModel', () {
    test('deserializa correctamente desde JSON (formato camelCase y PascalCase)', () {
      final jsonCamel = {
        'id': 1,
        'code': 'kW',
        'name': 'Kilovatios',
        'isActive': true,
      };

      final model = UnitOfMeasureModel.fromJson(jsonCamel);
      expect(model.id, 1);
      expect(model.code, 'kW');
      expect(model.name, 'Kilovatios');
      expect(model.isActive, true);
      expect(model.displayName, 'kW (Kilovatios)');

      final jsonPascal = {
        'UnidadMedidaId': '2',
        'Codigo': 'PSI',
        'Nombre': 'Libras por pulgada cuadrada',
        'Activo': 1,
      };

      final modelPascal = UnitOfMeasureModel.fromJson(jsonPascal);
      expect(modelPascal.id, 2);
      expect(modelPascal.code, 'PSI');
      expect(modelPascal.name, 'Libras por pulgada cuadrada');
      expect(modelPascal.isActive, true);
    });

    test('serializa a JSON correctamente', () {
      const model = UnitOfMeasureModel(
        id: 3,
        code: '°C',
        name: 'Grados Celsius',
        isActive: true,
      );

      final json = model.toJson();
      expect(json['id'], 3);
      expect(json['code'], '°C');
      expect(json['name'], 'Grados Celsius');
      expect(json['isActive'], true);
    });
  });

  group('AssetAttributeDefinitionModel', () {
    test('deserializa correctamente desde JSON', () {
      final json = {
        'id': 10,
        'name': 'Potencia',
        'description': 'Potencia nominal',
        'defaultUnitId': 1,
        'defaultUnitCode': 'kW',
        'defaultUnitName': 'Kilovatios',
        'isActive': true,
      };

      final model = AssetAttributeDefinitionModel.fromJson(json);
      expect(model.id, 10);
      expect(model.name, 'Potencia');
      expect(model.description, 'Potencia nominal');
      expect(model.defaultUnitId, 1);
      expect(model.defaultUnitCode, 'kW');
      expect(model.displayName, 'Potencia [kW]');
    });

    test('deserializa atributo sin unidad por defecto', () {
      final json = {
        'AtributoId': '15',
        'Nombre': 'Tipo de Refrigerante',
        'Descripcion': 'Gas refrigerante',
        'UnidadMedidaIdDefecto': null,
        'Activo': true,
      };

      final model = AssetAttributeDefinitionModel.fromJson(json);
      expect(model.id, 15);
      expect(model.name, 'Tipo de Refrigerante');
      expect(model.defaultUnitId, isNull);
      expect(model.displayName, 'Tipo de Refrigerante');
    });
  });
}
