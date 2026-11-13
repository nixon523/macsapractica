import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/work_orders/data/models/work_order_model.dart';
import 'package:macsapractica/features/work_orders/domain/entities/work_order.dart';

void main() {
  group('WorkOrderMaterial.fromMap', () {
    test('deserializa correctamente con nombres PascalCase desde SQL Server', () {
      final jsonSql = {
        'LineNum': 1,
        'Description': 'Empaque de teflón 2 pulgadas',
        'Quantity': 3.5,
        'Unit': 'm',
      };

      final material = WorkOrderMaterial.fromMap(jsonSql);

      expect(material.description, 'Empaque de teflón 2 pulgadas');
      expect(material.quantity, 3.5);
      expect(material.unit, 'm');
    });

    test('deserializa correctamente con nombres camelCase', () {
      final jsonCamel = {
        'description': 'Rodamiento SKF 6204',
        'quantity': 2,
        'unit': 'pz',
      };

      final material = WorkOrderMaterial.fromMap(jsonCamel);

      expect(material.description, 'Rodamiento SKF 6204');
      expect(material.quantity, 2.0);
      expect(material.unit, 'pz');
    });
  });

  group('WorkOrderModel.fromJson con MaterialsJson de SQL Server', () {
    test('parsea correctamente los materiales embebidos como JSON string', () {
      final row = {
        'WorkOrderId': 'OT-2026-0004',
        'AssetCode': 'A003-001',
        'AssetName': 'Línea de Empaque',
        'AreaId': 'A003',
        'Description': 'Revisión técnica',
        'Status': 'inProgress',
        'Priority': 'high',
        'MaterialsJson':
            '[{"LineNum":1,"Description":"Aceite sintético ISO VG 220","Quantity":2.5,"Unit":"gal"}]',
        'WorkTypesCsv': 'corrective,mechanical',
      };

      final model = WorkOrderModel.fromJson(row);

      expect(model.id, 'OT-2026-0004');
      expect(model.materials.length, 1);
      expect(model.materials.first.description, 'Aceite sintético ISO VG 220');
      expect(model.materials.first.quantity, 2.5);
      expect(model.materials.first.unit, 'gal');
    });
  });
}
