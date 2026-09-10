import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/work_order.dart';
import '../models/work_order_model.dart';

/// DataSource remoto de Órdenes de Trabajo contra la API REST (SQL Server).
class WorkOrderRemoteDataSource {
  const WorkOrderRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<WorkOrder>> getAllWorkOrders({
    WorkOrderStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.workOrders,
      queryParameters: {
        if (status != null) 'status': status.name,
      },
    );

    if (response is List) {
      final list = response
          .whereType<Map<String, dynamic>>()
          .map((json) => WorkOrderModel.fromJson(json))
          .toList();

      final filtered = list.where((order) {
        if (startDate != null &&
            order.createdAt != null &&
            order.createdAt!.isBefore(startDate)) {
          return false;
        }
        if (endDate != null &&
            order.createdAt != null &&
            order.createdAt!.isAfter(endDate)) {
          return false;
        }
        return true;
      }).toList();

      filtered.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return filtered;
    }
    return [];
  }

  Future<List<WorkOrder>> getOpenWorkOrders() async {
    final response = await _apiClient.get(ApiEndpoints.openWorkOrders);
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => WorkOrderModel.fromJson(json))
          .toList();
    }
    return [];
  }

  Future<List<WorkOrder>> getWorkOrdersForAsset(String assetId) async {
    final list = await getAllWorkOrders();
    final filtered = list.where((o) => o.assetId == assetId).toList();
    filtered.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return filtered;
  }

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
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.workOrders,
      body: {
        'assetCode': assetId,
        'assetName': assetName,
        'areaId': areaId ?? '',
        'areaName': areaName,
        'description': description.trim(),
        'priority': priority.name,
        'workTypes': requestedWorkTypes,
        'assignedTo': assignedTo,
        'assignedStaffCount': assignedStaffCount,
        'estimatedHours': estimatedHours,
        'materials': materials
            .map((m) => {
                  'description': m.description,
                  'quantity': m.quantity,
                  'unit': m.unit,
                })
            .toList(),
        'scheduledDate': scheduledDate?.toIso8601String(),
        'reportId': reportId != null ? int.tryParse(reportId) : null,
        'preventiveScheduleId': preventiveScheduleId,
        'planPreventivoId': preventiveScheduleId,
      },
    );

    String newNumber = '';
    if (response is Map<String, dynamic>) {
      newNumber = (response['WorkOrderNumber'] ??
              response['workOrderNumber'] ??
              response['id'] ??
              '')
          .toString();
    }

    return WorkOrderModel(
      id: newNumber.isNotEmpty ? newNumber : 'OT-2026-0001',
      correlativeNumber: newNumber.isNotEmpty ? newNumber : 'OT-2026-0001',
      assetId: assetId,
      assetName: assetName,
      areaId: areaId,
      areaName: areaName,
      description: description,
      status: WorkOrderStatus.pending,
      priority: priority,
      requestedWorkTypes: requestedWorkTypes,
      assignedTo: assignedTo,
      assignedStaffCount: assignedStaffCount,
      estimatedHours: estimatedHours,
      materials: materials,
      scheduledDate: scheduledDate,
      reportId: reportId,
      preventiveScheduleId: preventiveScheduleId,
      createdByUserId: createdByUserId,
      createdByUserName: createdByUserName,
      createdAt: DateTime.now(),
    );
  }

  Future<void> updateStatus({
    required String workOrderId,
    required WorkOrderStatus status,
    required String userId,
    required String userName,
  }) async {
    await _apiClient.patch(
      ApiEndpoints.updateWorkOrderStatus(workOrderId),
      body: {
        'newStatus': status.name,
      },
    );
  }

  Future<void> updateWorkOrderDetails({
    required WorkOrder workOrder,
    required String userId,
    required String userName,
  }) async {
    await _apiClient.put(
      ApiEndpoints.updateWorkOrderDetails(workOrder.id),
      body: {
        'description': workOrder.description,
        'priority': workOrder.priority.name,
        'assignedTo': workOrder.assignedTo,
        'assignedStaffCount': workOrder.assignedStaffCount,
        'estimatedHours': workOrder.estimatedHours,
        'actualHours': workOrder.actualHours,
        'workDoneDescription': workOrder.workDoneDescription,
        'isCompleted': workOrder.isCompleted,
        'unfulfillmentReason': workOrder.unfulfillmentReason,
        'reprogramDate': workOrder.reprogramDate?.toIso8601String(),
        'scheduledDate': workOrder.scheduledDate?.toIso8601String(),
        'materials': workOrder.materials
            .map((m) => {
                  'description': m.description,
                  'quantity': m.quantity,
                  'unit': m.unit,
                })
            .toList(),
        'workTypes': workOrder.requestedWorkTypes,
      },
    );
  }
}
