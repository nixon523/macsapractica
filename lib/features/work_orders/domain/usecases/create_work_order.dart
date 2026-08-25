import '../../../../core/usecases/usecase.dart';
import '../entities/work_order.dart';
import '../repositories/work_order_repository.dart';

class CreateWorkOrderParams {
  const CreateWorkOrderParams({
    required this.assetId,
    required this.assetName,
    this.areaId,
    this.areaName,
    required this.description,
    this.priority = WorkOrderPriority.medium,
    this.requestedWorkTypes = const [],
    this.assignedTo,
    this.assignedStaffCount,
    this.estimatedHours,
    this.materials = const [],
    this.scheduledDate,
    this.reportId,
    required this.createdByUserId,
    required this.createdByUserName,
  });

  final String assetId;
  final String assetName;
  final String? areaId;
  final String? areaName;
  final String description;
  final WorkOrderPriority priority;
  final List<String> requestedWorkTypes;
  final String? assignedTo;
  final int? assignedStaffCount;
  final double? estimatedHours;
  final List<WorkOrderMaterial> materials;
  final DateTime? scheduledDate;
  final String? reportId;
  final String createdByUserId;
  final String createdByUserName;
}

class CreateWorkOrderUseCase implements UseCase<WorkOrder, CreateWorkOrderParams> {
  const CreateWorkOrderUseCase(this._repository);

  final WorkOrderRepository _repository;

  @override
  Future<WorkOrder> call(CreateWorkOrderParams params) {
    return _repository.createWorkOrder(
      assetId: params.assetId,
      assetName: params.assetName,
      areaId: params.areaId,
      areaName: params.areaName,
      description: params.description,
      priority: params.priority,
      requestedWorkTypes: params.requestedWorkTypes,
      assignedTo: params.assignedTo,
      assignedStaffCount: params.assignedStaffCount,
      estimatedHours: params.estimatedHours,
      materials: params.materials,
      scheduledDate: params.scheduledDate,
      reportId: params.reportId,
      createdByUserId: params.createdByUserId,
      createdByUserName: params.createdByUserName,
    );
  }
}
