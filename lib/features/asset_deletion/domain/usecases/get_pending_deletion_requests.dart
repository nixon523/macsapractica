import '../../../../core/usecases/usecase.dart';
import '../entities/asset_delete_request.dart';
import '../repositories/asset_delete_repository.dart';

class GetPendingDeletionRequestsUseCase
    implements UseCase<List<AssetDeleteRequest>, NoParams> {
  const GetPendingDeletionRequestsUseCase(this._repository);

  final AssetDeleteRepository _repository;

  @override
  Future<List<AssetDeleteRequest>> call(NoParams params) {
    return _repository.getPendingRequests();
  }
}
