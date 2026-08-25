import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/preventive_schedules/domain/entities/preventive_schedule.dart';

void main() {
  group('PreventiveSchedule Entity & Frequencies', () {
    test('calculateNextDate calcula correctamente según la frecuencia', () {
      final baseDate = DateTime(2026, 1, 1);

      expect(
        ScheduleFrequency.weekly.calculateNextDate(baseDate),
        DateTime(2026, 1, 8),
      );
      expect(
        ScheduleFrequency.biweekly.calculateNextDate(baseDate),
        DateTime(2026, 1, 16),
      );
      expect(
        ScheduleFrequency.monthly.calculateNextDate(baseDate),
        DateTime(2026, 1, 31),
      );
    });

    test('alertLevel clasifica adecuadamente según días restantes', () {
      final now = DateTime.now();

      // Vencido
      final overdue = PreventiveSchedule(
        id: 'PM-001',
        assetId: 'EQ-01',
        areaId: 'A1',
        maintenanceType: 'Lubricación',
        frequency: ScheduleFrequency.monthly,
        startDate: now.subtract(const Duration(days: 40)),
        nextDate: now.subtract(const Duration(days: 2)),
        status: ScheduleStatus.active,
      );
      expect(overdue.isOverdue, isTrue);
      expect(overdue.alertLevel, PreventiveAlertLevel.overdue);

      // Urgente (<= 2 días / 48h)
      final urgent = PreventiveSchedule(
        id: 'PM-002',
        assetId: 'EQ-01',
        areaId: 'A1',
        maintenanceType: 'Lubricación',
        frequency: ScheduleFrequency.monthly,
        startDate: now.subtract(const Duration(days: 28)),
        nextDate: now.add(const Duration(days: 1)),
        status: ScheduleStatus.active,
      );
      expect(urgent.isOverdue, isFalse);
      expect(urgent.alertLevel, PreventiveAlertLevel.urgent);

      // Próximo (3-7 días)
      final upcoming = PreventiveSchedule(
        id: 'PM-003',
        assetId: 'EQ-01',
        areaId: 'A1',
        maintenanceType: 'Lubricación',
        frequency: ScheduleFrequency.monthly,
        startDate: now.subtract(const Duration(days: 25)),
        nextDate: now.add(const Duration(days: 5)),
        status: ScheduleStatus.active,
      );
      expect(upcoming.alertLevel, PreventiveAlertLevel.upcoming);

      // Al día (>7 días)
      final onSchedule = PreventiveSchedule(
        id: 'PM-004',
        assetId: 'EQ-01',
        areaId: 'A1',
        maintenanceType: 'Lubricación',
        frequency: ScheduleFrequency.monthly,
        startDate: now,
        nextDate: now.add(const Duration(days: 20)),
        status: ScheduleStatus.active,
      );
      expect(onSchedule.alertLevel, PreventiveAlertLevel.onSchedule);
    });

    test('PreventiveMaterial serializa y deserializa correctamente', () {
      final material = PreventiveMaterial(
        name: 'Grasa Sintética ISO 220',
        quantity: 2.5,
        unit: 'kg',
      );

      final map = material.toMap();
      final fromMap = PreventiveMaterial.fromMap(map);

      expect(fromMap.name, 'Grasa Sintética ISO 220');
      expect(fromMap.quantity, 2.5);
      expect(fromMap.unit, 'kg');
    });
  });
}
