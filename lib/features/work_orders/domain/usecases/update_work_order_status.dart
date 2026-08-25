import '../../../../core/usecases/usecase.dart';
import '../entities/work_order.dart';
import '../repositories/work_order_repository.dart';

class UpdateWorkOrderStatusParams {
  const UpdateWorkOrderStatusParams({
    required this.workOrderId,
    required this.status,
    required this.userId,
    required this.userName,
  });

  final String workOrderId;
  final WorkOrderStatus status;
  final String userId;
  final String userName;
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
    );
  }
}
