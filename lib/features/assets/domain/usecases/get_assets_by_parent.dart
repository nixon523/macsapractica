import '../../../../core/usecases/usecase.dart';
import '../entities/asset.dart';
import '../repositories/asset_repository.dart';

class GetAssetsByParentParams {
  const GetAssetsByParentParams({
    required this.areaId,
    this.parentAssetId,
    this.forceRefresh = false,
  });

  final String areaId;
  final String? parentAssetId;
  final bool forceRefresh;
}

class GetAssetsByParentUseCase
    implements UseCase<List<Asset>, GetAssetsByParentParams> {
  const GetAssetsByParentUseCase(this._repository);

  final AssetRepository _repository;

  @override
  Future<List<Asset>> call(GetAssetsByParentParams params) {
    return _repository.getAssetsByParent(
      areaId: params.areaId,
      parentAssetId: params.parentAssetId,
      forceRefresh: params.forceRefresh,
    );
  }
}
