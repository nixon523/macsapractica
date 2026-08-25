import '../../domain/entities/work_order.dart';
import '../../domain/repositories/work_order_repository.dart';
import '../datasources/work_order_remote_datasource.dart';

class WorkOrderRepositoryImpl implements WorkOrderRepository {
  const WorkOrderRepositoryImpl(this._remoteDataSource);

  final WorkOrderRemoteDataSource _remoteDataSource;

  @override
  Future<List<WorkOrder>> getAllWorkOrders({
    WorkOrderStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _remoteDataSource.getAllWorkOrders(
      status: status,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<List<WorkOrder>> getWorkOrdersForAsset(String assetId) {
    return _remoteDataSource.getWorkOrdersForAsset(assetId);
  }

  @override
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
    required String createdByUserId,
    required String createdByUserName,
  }) {
    return _remoteDataSource.createWorkOrder(
      assetId: assetId,
      assetName: assetName,
      areaId: areaId,
      areaName: areaName,
      description: description,
      priority: priority,
      requestedWorkTypes: requestedWorkTypes,
      assignedTo: assignedTo,
      assignedStaffCount: assignedStaffCount,
      estimatedHours: estimatedHours,
      materials: materials,
      scheduledDate: scheduledDate,
      reportId: reportId,
      createdByUserId: createdByUserId,
      createdByUserName: createdByUserName,
    );
  }

  @override
  Future<void> updateStatus({
    required String workOrderId,
    required WorkOrderStatus status,
    required String userId,
    required String userName,
  }) {
    return _remoteDataSource.updateStatus(
      workOrderId: workOrderId,
      status: status,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<void> updateWorkOrderDetails({
    required WorkOrder workOrder,
    required String userId,
    required String userName,
  }) {
    return _remoteDataSource.updateWorkOrderDetails(
      workOrder: workOrder,
      userId: userId,
      userName: userName,
    );
  }
}
