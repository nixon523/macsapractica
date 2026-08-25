import 'package:flutter_test/flutter_test.dart';

import 'package:macsapractica/features/breakdown_reports/domain/entities/breakdown_report.dart';
import 'package:macsapractica/features/breakdown_reports/presentation/viewmodels/my_reports_notifications_viewmodel.dart';

void main() {
  group('MyReportsNotificationsViewModel.processSnapshot', () {
    test('el primer snapshot siembra los reportes sin disparar alerta', () {
      final vm = MyReportsNotificationsViewModel();
      vm.processSnapshot([_report('r1'), _report('r2')]);

      expect(vm.pendingUnreadCount, 0);
      expect(vm.latestOutcome, isNull);
    });

    test('detecta cuando un reporte pasa a inWorkOrder', () {
      final vm = MyReportsNotificationsViewModel();
      vm.processSnapshot([_report('r1')]);
      vm.processSnapshot([
        _report('r1', status: BreakdownReportStatus.inWorkOrder),
      ]);

      expect(vm.pendingUnreadCount, 1);
      expect(vm.latestOutcome?.kind, ReportOutcomeKind.workOrderGenerated);
    });

    test('detecta cuando un reporte pasa a rejected', () {
      final vm = MyReportsNotificationsViewModel();
      vm.processSnapshot([_report('r1')]);
      vm.processSnapshot([
        _report('r1', status: BreakdownReportStatus.rejected),
      ]);

      expect(vm.pendingUnreadCount, 1);
      expect(vm.latestOutcome?.kind, ReportOutcomeKind.rejected);
    });

    test('consumeLatestOutcome devuelve el resultado y limpia la alerta', () {
      final vm = MyReportsNotificationsViewModel();
      vm.processSnapshot([_report('r1')]);
      vm.processSnapshot([
        _report('r1', status: BreakdownReportStatus.inWorkOrder),
      ]);

      final consumed = vm.consumeLatestOutcome();
      expect(consumed?.report.id, 'r1');
      expect(vm.latestOutcome, isNull);
    });

    test('un reporte recién creado (reported) no dispara alerta', () {
      final vm = MyReportsNotificationsViewModel();
      vm.processSnapshot([]);
      vm.processSnapshot([_report('r1')]);

      expect(vm.pendingUnreadCount, 0);
      expect(vm.latestOutcome, isNull);
    });

    test('una transición ya conocida no vuelve a disparar alerta', () {
      final vm = MyReportsNotificationsViewModel();
      vm.processSnapshot([_report('r1')]);
      vm.processSnapshot([
        _report('r1', status: BreakdownReportStatus.inWorkOrder),
      ]);
      vm.consumeLatestOutcome();
      vm.processSnapshot([
        _report('r1', status: BreakdownReportStatus.inWorkOrder),
      ]);

      expect(vm.latestOutcome, isNull);
      expect(vm.pendingUnreadCount, 1);
    });

    test('markSectionSeen limpia el contador de no leídos', () {
      final vm = MyReportsNotificationsViewModel();
      vm.processSnapshot([_report('r1')]);
      vm.processSnapshot([
        _report('r1', status: BreakdownReportStatus.rejected),
      ]);

      expect(vm.pendingUnreadCount, 1);

      vm.markSectionSeen();

      expect(vm.pendingUnreadCount, 0);
    });

    test('stop reinicia el estado', () {
      final vm = MyReportsNotificationsViewModel();
      vm.processSnapshot([_report('r1')]);
      vm.processSnapshot([
        _report('r1', status: BreakdownReportStatus.inWorkOrder),
      ]);

      vm.stop();

      expect(vm.pendingUnreadCount, 0);
      expect(vm.latestOutcome, isNull);
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
