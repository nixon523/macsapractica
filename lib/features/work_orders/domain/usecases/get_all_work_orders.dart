import '../../../../core/usecases/usecase.dart';
import '../entities/work_order.dart';
import '../repositories/work_order_repository.dart';

class GetAllWorkOrdersParams {
  const GetAllWorkOrdersParams({
    this.status,
    this.startDate,
    this.endDate,
  });

  final WorkOrderStatus? status;
  final DateTime? startDate;
  final DateTime? endDate;
}

class GetAllWorkOrdersUseCase
    implements UseCase<List<WorkOrder>, GetAllWorkOrdersParams> {
  const GetAllWorkOrdersUseCase(this._repository);

  final WorkOrderRepository _repository;

  @override
  Future<List<WorkOrder>> call([
    GetAllWorkOrdersParams params = const GetAllWorkOrdersParams(),
  ]) {
    return _repository.getAllWorkOrders(
      status: params.status,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}
