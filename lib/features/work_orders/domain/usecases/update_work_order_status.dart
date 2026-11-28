import '../../../../core/usecases/usecase.dart';
import '../entities/work_order.dart';
import '../repositories/work_order_repository.dart';

class UpdateWorkOrderStatusParams {
  const UpdateWorkOrderStatusParams({
    required this.workOrderId,
    required this.status,
    required this.userId,
    required this.userName,
    this.motivoPausa,
    this.motivoReprogramacion,
    this.fechaReprogramacion,
    this.horasReales,
    this.trabajoRealizado,
    this.observaciones,
  });

  final String workOrderId;
  final WorkOrderStatus status;
  final String userId;
  final String userName;
  final String? motivoPausa;
  final String? motivoReprogramacion;
  final DateTime? fechaReprogramacion;
  final double? horasReales;
  final String? trabajoRealizado;
  final String? observaciones;
}

class UpdateWorkOrderStatusUseCase
    implements UseCase<void, UpdateWorkOrderStatusParams> {
  const UpdateWorkOrderStatusUseCase(this._repository);

  final WorkOrderRepository _repository;

  @override
  Future<void> call(UpdateWorkOrderStatusParams params) {
    return _repository.updateStatus(
      workOrderId: params.workOrderId,
      status: params.status,
      userId: params.userId,
      userName: params.userName,
      motivoPausa: params.motivoPausa,
      motivoReprogramacion: params.motivoReprogramacion,
      fechaReprogramacion: params.fechaReprogramacion,
      horasReales: params.horasReales,
      trabajoRealizado: params.trabajoRealizado,
      observaciones: params.observaciones,
    );
  }
}
