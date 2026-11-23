import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/dashboard/data/models/cost_center_maintenance_stats_model.dart';

void main() {
  group('CostCenterMaintenanceStatsModel', () {
    test('deserializa correctamente desde JSON (camelCase y PascalCase)', () {
      final json = {
        'costCenter': 'CC-39',
        'areaId': 'A005',
        'areaName': 'EMPAQUE - MASTERIZADO',
        'totalMaintenance': 12,
        'completed': 8,
        'inProgress': 3,
        'cancelled': 1,
        'corrective': 5,
        'preventive': 5,
        'predictive': 1,
        'improvement': 1,
        'otherTypes': 0,
        'totalRealHours': 34.5,
        'totalEstimatedHours': 30.0,
      };

      final model = CostCenterMaintenanceStatsModel.fromJson(json);
      expect(model.costCenter, 'CC-39');
      expect(model.areaId, 'A005');
      expect(model.areaName, 'EMPAQUE - MASTERIZADO');
      expect(model.totalMaintenance, 12);
      expect(model.completed, 8);
      expect(model.inProgress, 3);
      expect(model.cancelled, 1);
      expect(model.corrective, 5);
      expect(model.preventive, 5);
      expect(model.predictive, 1);
      expect(model.improvement, 1);
      expect(model.otherTypes, 0);
      expect(model.totalRealHours, 34.5);
      expect(model.totalEstimatedHours, 30.0);
    });

    test('deserializa correctamente con nombres PascalCase de SQL Server', () {
      final jsonPascal = {
        'CentroCosto': 'CC-41',
        'AreaId': 'A006',
        'Nombre': 'CLASIFICADO',
        'TotalMantenimientos': '7',
        'Completados': '6',
        'EnProceso': '1',
        'Canceladas': '0',
        'Correctivos': '2',
        'Preventivos': '5',
        'Predictivos': '0',
        'Mejoras': '0',
        'OtrosTipos': '0',
        'HorasRealesTotales': '18.25',
        'HorasEstimadasTotales': '20.0',
      };

      final model = CostCenterMaintenanceStatsModel.fromJson(jsonPascal);
      expect(model.costCenter, 'CC-41');
      expect(model.areaId, 'A006');
      expect(model.areaName, 'CLASIFICADO');
      expect(model.totalMaintenance, 7);
      expect(model.completed, 6);
      expect(model.inProgress, 1);
      expect(model.corrective, 2);
      expect(model.preventive, 5);
      expect(model.totalRealHours, 18.25);
    });
  });

  group('CostCenterMaintenanceDetailModel', () {
    test('deserializa ordenes de trabajo de detalle', () {
      final json = {
        'workOrderId': 'OT-2026-0001',
        'assetCode': 'A005-001',
        'assetName': 'Clasificadora 1',
        'areaId': 'A005',
        'areaName': 'Empaque',
        'costCenter': 'CC-39',
        'description': 'Mantenimiento preventivo bimensual',
        'status': 'completed',
        'priority': 'alta',
        'assignedTo': 'Carlos Mendoza',
        'estimatedHours': 4.0,
        'actualHours': 4.5,
        'createdAt': '2026-11-10T08:00:00.000Z',
        'mainMaintenanceType': 'preventive',
        'workTypesText': 'preventivo, electrico',
      };

      final model = CostCenterMaintenanceDetailModel.fromJson(json);
      expect(model.workOrderId, 'OT-2026-0001');
      expect(model.assetCode, 'A005-001');
      expect(model.assetName, 'Clasificadora 1');
      expect(model.costCenter, 'CC-39');
      expect(model.mainMaintenanceType, 'preventive');
      expect(model.actualHours, 4.5);
      expect(model.createdAt, DateTime.parse('2026-11-10T08:00:00.000Z'));
    });
  });
}
