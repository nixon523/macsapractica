import 'package:flutter_test/flutter_test.dart';

import 'package:macsapractica/features/work_orders/domain/entities/work_order.dart';
import 'package:macsapractica/features/work_orders/presentation/viewmodels/work_order_alerts_viewmodel.dart';

void main() {
  group('WorkOrderAlertsViewModel.processSnapshot', () {
    test('el primer snapshot siembra las OTs sin disparar alerta', () {
      final vm = WorkOrderAlertsViewModel();
      vm.processSnapshot([
        _order('ot1', priority: WorkOrderPriority.high),
        _order('ot2', priority: WorkOrderPriority.medium),
      ]);

      expect(vm.pendingHighPriorityCount, 1);
      expect(vm.totalOpenCount, 2);
      expect(vm.latestAlert, isNull);
    });

    test('una OT de alta prioridad nueva en snapshot posterior dispara alerta', () {
      final vm = WorkOrderAlertsViewModel();
      vm.processSnapshot([_order('ot1', priority: WorkOrderPriority.low)]);
      vm.processSnapshot([
        _order('ot1', priority: WorkOrderPriority.low),
        _order('ot2', priority: WorkOrderPriority.high),
      ]);

      expect(vm.pendingHighPriorityCount, 1);
      expect(vm.latestAlert?.id, 'ot2');
    });

    test('consumeLatestAlert devuelve la OT y limpia la alerta', () {
      final vm = WorkOrderAlertsViewModel();
      vm.processSnapshot([]);
      vm.processSnapshot([_order('ot1', priority: WorkOrderPriority.high)]);

      final consumed = vm.consumeLatestAlert();
      expect(consumed?.id, 'ot1');
      expect(vm.latestAlert, isNull);
    });

    test('las OTs ya conocidas no vuelven a disparar alerta', () {
      final vm = WorkOrderAlertsViewModel();
      vm.processSnapshot([_order('ot1', priority: WorkOrderPriority.low)]);
      vm.processSnapshot([
        _order('ot1', priority: WorkOrderPriority.low),
        _order('ot2', priority: WorkOrderPriority.high),
      ]);
      vm.consumeLatestAlert();
      vm.processSnapshot([
        _order('ot1', priority: WorkOrderPriority.low),
        _order('ot2', priority: WorkOrderPriority.high),
      ]);

      expect(vm.latestAlert, isNull);
      expect(vm.pendingHighPriorityCount, 1);
    });

    test('calcula correctamente el conteo de OTs vencidas', () {
      final vm = WorkOrderAlertsViewModel();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      vm.processSnapshot([
        _order('ot1', scheduledDate: yesterday),
        _order('ot2', scheduledDate: tomorrow),
      ]);

      expect(vm.overdueCount, 1);
      expect(vm.totalOpenCount, 2);
      expect(vm.badgeCount, 2);
    });

    test('stop reinicia el estado', () {
      final vm = WorkOrderAlertsViewModel();
      vm.processSnapshot([_order('ot1', priority: WorkOrderPriority.high)]);
      vm.processSnapshot([
        _order('ot1', priority: WorkOrderPriority.high),
        _order('ot2', priority: WorkOrderPriority.high),
      ]);

      vm.stop();

      expect(vm.pendingHighPriorityCount, 0);
      expect(vm.overdueCount, 0);
      expect(vm.totalOpenCount, 0);
      expect(vm.latestAlert, isNull);
      expect(vm.isListening, isFalse);
    });
  });
}

WorkOrder _order(
  String id, {
  WorkOrderPriority priority = WorkOrderPriority.medium,
  WorkOrderStatus status = WorkOrderStatus.pending,
  DateTime? scheduledDate,
}) {
  return WorkOrder(
    id: id,
    correlativeNumber: '0001',
    assetId: 'EQ-001',
    assetName: 'Torno CNC',
    areaId: 'A-01',
    description: 'Revisión y ajuste.',
    status: status,
    priority: priority,
    scheduledDate: scheduledDate,
  );
}
