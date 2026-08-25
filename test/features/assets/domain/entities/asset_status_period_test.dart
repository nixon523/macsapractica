import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/assets/domain/entities/asset.dart';

void main() {
  group('AssetStatusPeriod Entity', () {
    test('serializa y deserializa correctamente con toMap y fromMap', () {
      final now = DateTime(2026, 8, 20, 10, 0);
      final ended = DateTime(2026, 8, 20, 14, 30);

      final period = AssetStatusPeriod(
        status: AssetStatus.inactive,
        startedAt: now,
        endedAt: ended,
        areaId: 'A1',
        reason: 'Falla mecánica',
        userId: 'u1',
        userName: 'Carlos Técnico',
      );

      final map = period.toMap();
      expect(map['status'], 'inactive');
      expect(map['startedAt'], now.toIso8601String());
      expect(map['endedAt'], ended.toIso8601String());
      expect(map['areaId'], 'A1');
      expect(map['reason'], 'Falla mecánica');
      expect(map['userId'], 'u1');
      expect(map['userName'], 'Carlos Técnico');

      final fromMap = AssetStatusPeriod.fromMap(map);
      expect(fromMap.status, AssetStatus.inactive);
      expect(fromMap.startedAt, now);
      expect(fromMap.endedAt, ended);
      expect(fromMap.areaId, 'A1');
      expect(fromMap.reason, 'Falla mecánica');
      expect(fromMap.isCurrent, isFalse);
      expect(fromMap.duration, const Duration(hours: 4, minutes: 30));
    });

    test('isCurrent es true cuando endedAt es null', () {
      final period = AssetStatusPeriod(
        status: AssetStatus.active,
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        endedAt: null,
        areaId: 'A1',
      );

      expect(period.isCurrent, isTrue);
      expect(period.duration.inMinutes, greaterThanOrEqualTo(119));
    });
  });

  group('Asset Uptime, Downtime & Availability metrics', () {
    test('calcula uptime, downtime, inactiveCount y availabilityPercentage', () {
      final p1 = AssetStatusPeriod(
        status: AssetStatus.active,
        startedAt: DateTime(2026, 8, 1, 0, 0),
        endedAt: DateTime(2026, 8, 11, 0, 0), // 10 días activo (240h)
        areaId: 'A1',
        reason: 'Operación normal',
      );
      final p2 = AssetStatusPeriod(
        status: AssetStatus.inactive,
        startedAt: DateTime(2026, 8, 11, 0, 0),
        endedAt: DateTime(2026, 8, 12, 0, 0), // 1 día inactivo (24h)
        areaId: 'A1',
        reason: 'Mantenimiento correctivo',
      );
      final p3 = AssetStatusPeriod(
        status: AssetStatus.active,
        startedAt: DateTime(2026, 8, 12, 0, 0),
        endedAt: DateTime(2026, 8, 21, 0, 0), // 9 días activo (216h)
        areaId: 'A1',
        reason: 'Reactivado',
      );

      final asset = Asset(
        id: 'A1-001',
        name: 'Bomba Principal',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: [],
        status: AssetStatus.active,
        dynamicAttributes: {},
        statusHistory: [p1, p2, p3],
      );

      // Total Uptime: 10 días + 9 días = 19 días (456 horas)
      expect(asset.totalUptime.inHours, 456);
      // Total Downtime: 1 día (24 horas)
      expect(asset.totalDowntime.inHours, 24);
      // Total Inactive Count: 1 parada
      expect(asset.inactiveCount, 1);
      // Availability: 456 / (456 + 24) = 456 / 480 = 95.0%
      expect(asset.availabilityPercentage, closeTo(95.0, 0.01));
    });

    test('retorna 100% de disponibilidad cuando no hay historial de paradas', () {
      const asset = Asset(
        id: 'A1-002',
        name: 'Compresor Nuevo',
        areaId: 'A1',
        stationId: 'S1',
        level: AssetLevel.equipment,
        ancestors: [],
        status: AssetStatus.active,
        dynamicAttributes: {},
        statusHistory: [],
      );

      expect(asset.totalDowntime, Duration.zero);
      expect(asset.inactiveCount, 0);
      expect(asset.availabilityPercentage, 100.0);
    });
  });
}
