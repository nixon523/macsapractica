import '../../../../core/usecases/usecase.dart';
import '../entities/asset_delete_request.dart';
import '../repositories/asset_delete_repository.dart';

class GetDeletionRequestByAssetParams {
  const GetDeletionRequestByAssetParams(this.assetId);

  final String assetId;
}

class GetDeletionRequestByAssetUseCase
    implements UseCase<AssetDeleteRequest?, GetDeletionRequestByAssetParams> {
  const GetDeletionRequestByAssetUseCase(this._repository);

  final AssetDeleteRepository _repository;

  @override
  Future<AssetDeleteRequest?> call(GetDeletionRequestByAssetParams params) {
    return _repository.getPendingRequestByAsset(params.assetId);
  }
}
