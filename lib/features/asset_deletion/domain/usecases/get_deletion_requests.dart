import '../../../../core/usecases/usecase.dart';
import '../entities/asset_delete_request.dart';
import '../repositories/asset_delete_repository.dart';

class GetDeletionRequestsParams {
  const GetDeletionRequestsParams({
    this.startDate,
    this.endDate,
  });

  final DateTime? startDate;
  final DateTime? endDate;
}

class GetDeletionRequestsUseCase
    implements UseCase<List<AssetDeleteRequest>, GetDeletionRequestsParams> {
  const GetDeletionRequestsUseCase(this._repository);

  final AssetDeleteRepository _repository;

  @override
  Future<List<AssetDeleteRequest>> call([
    GetDeletionRequestsParams params = const GetDeletionRequestsParams(),
  ]) {
    return _repository.getAllRequests(
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}
