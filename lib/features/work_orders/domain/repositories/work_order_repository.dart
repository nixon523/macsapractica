import '../entities/work_order.dart';

abstract class WorkOrderRepository {
  Future<List<WorkOrder>> getAllWorkOrders({
    WorkOrderStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<List<WorkOrder>> getWorkOrdersForAsset(String assetId);

  /// Crea una OT con ID secuencial (`OT-2026-0001`...) vía transacción
  /// sobre `counters/work_orders`.
  Future<WorkOrder> createWorkOrder({
    required String assetId,
    required String assetName,
    String? areaId,
    String? areaName,
    required String description,
    WorkOrderPriority priority = WorkOrderPriority.medium,
    List<String> requestedWorkTypes = const [],
    String? assignedTo,
    int? assignedStaffCount,
    double? estimatedHours,
    List<WorkOrderMaterial> materials = const [],
    DateTime? scheduledDate,
    String? reportId,
    String? preventiveScheduleId,
    required String createdByUserId,
    required String createdByUserName,
  });

  Future<void> updateStatus({
    required String workOrderId,
    required WorkOrderStatus status,
    required String userId,
    required String userName,
  });

  /// Actualiza los detalles de ejecución de mantenimiento, materiales, informe y firmas.
  Future<void> updateWorkOrderDetails({
    required WorkOrder workOrder,
    required String userId,
    required String userName,
  });
}
