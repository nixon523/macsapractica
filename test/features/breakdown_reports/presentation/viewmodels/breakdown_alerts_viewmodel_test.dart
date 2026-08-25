import 'package:flutter_test/flutter_test.dart';

import 'package:macsapractica/features/breakdown_reports/domain/entities/breakdown_report.dart';
import 'package:macsapractica/features/breakdown_reports/presentation/viewmodels/breakdown_alerts_viewmodel.dart';

void main() {
  group('BreakdownAlertsViewModel.processSnapshot', () {
    test('el primer snapshot siembra los reportes sin disparar alerta', () {
      final vm = BreakdownAlertsViewModel();
      vm.processSnapshot([_report('r1'), _report('r2')]);

      expect(vm.pendingCount, 2);
      expect(vm.latestNewReport, isNull);
    });

    test('un reporte nuevo en un snapshot posterior dispara la alerta', () {
      final vm = BreakdownAlertsViewModel();
      vm.processSnapshot([_report('r1')]);
      vm.processSnapshot([_report('r1'), _report('r2')]);

      expect(vm.pendingCount, 2);
      expect(vm.latestNewReport?.id, 'r2');
    });

    test('consumeLatestReport devuelve el reporte y limpia la alerta', () {
      final vm = BreakdownAlertsViewModel();
      vm.processSnapshot([]);
      vm.processSnapshot([_report('r1')]);

      final consumed = vm.consumeLatestReport();
      expect(consumed?.id, 'r1');
      expect(vm.latestNewReport, isNull);
    });

    test('los reportes ya conocidos no vuelven a disparar alerta', () {
      final vm = BreakdownAlertsViewModel();
      vm.processSnapshot([_report('r1')]);
      vm.processSnapshot([_report('r1'), _report('r2')]);
      vm.consumeLatestReport();
      vm.processSnapshot([_report('r1'), _report('r2')]);

      expect(vm.latestNewReport, isNull);
      expect(vm.pendingCount, 2);
    });

    test('el contador baja cuando el reporte deja de estar reportado', () {
      final vm = BreakdownAlertsViewModel();
      vm.processSnapshot([_report('r1'), _report('r2')]);
      vm.processSnapshot([_report('r1', status: BreakdownReportStatus.inWorkOrder)]);

      expect(vm.pendingCount, 1);
    });

    test('stop reinicia el estado', () {
      final vm = BreakdownAlertsViewModel();
      vm.processSnapshot([_report('r1')]);
      vm.processSnapshot([_report('r1'), _report('r2')]);

      vm.stop();

      expect(vm.pendingCount, 0);
      expect(vm.latestNewReport, isNull);
      expect(vm.isListening, isFalse);
    });
  });
}

BreakdownReport _report(
  String id, {
  BreakdownReportStatus status = BreakdownReportStatus.reported,
}) {
  return BreakdownReport(
    id: id,
    assetId: 'EQ-001',
    assetName: 'Bomba centrífuga',
    areaId: 'A-01',
    description: 'Fuga de aceite.',
    severity: BreakdownSeverity.medium,
    reportedByUserId: 'u1',
    reportedByUserName: 'reportador',
    reportedAt: DateTime(2026, 1, 1),
    status: status,
  );
}
