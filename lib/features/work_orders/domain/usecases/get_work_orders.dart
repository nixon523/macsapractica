import '../../../../core/usecases/usecase.dart';
import '../entities/work_order.dart';
import '../repositories/work_order_repository.dart';

class GetWorkOrdersParams {
  const GetWorkOrdersParams(this.assetId);

  final String assetId;
}

class GetWorkOrdersUseCase
    implements UseCase<List<WorkOrder>, GetWorkOrdersParams> {
  const GetWorkOrdersUseCase(this._repository);

  final WorkOrderRepository _repository;

  @override
  Future<List<WorkOrder>> call(GetWorkOrdersParams params) {
    return _repository.getWorkOrdersForAsset(params.assetId);
  }
}
