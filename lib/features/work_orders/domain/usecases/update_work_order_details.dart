import '../../../../core/usecases/usecase.dart';
import '../entities/work_order.dart';
import '../repositories/work_order_repository.dart';

class UpdateWorkOrderDetailsParams {
  const UpdateWorkOrderDetailsParams({
    required this.workOrder,
    required this.userId,
    required this.userName,
  });

  final WorkOrder workOrder;
  final String userId;
  final String userName;
}

class UpdateWorkOrderDetailsUseCase
    implements UseCase<void, UpdateWorkOrderDetailsParams> {
  const UpdateWorkOrderDetailsUseCase(this._repository);

  final WorkOrderRepository _repository;

  @override
  Future<void> call(UpdateWorkOrderDetailsParams params) {
    return _repository.updateWorkOrderDetails(
      workOrder: params.workOrder,
      userId: params.userId,
      userName: params.userName,
    );
  }
}
