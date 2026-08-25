import '../../../../core/usecases/usecase.dart';
import '../entities/asset.dart';
import '../repositories/asset_repository.dart';

class GetAssetsByAreaParams {
  const GetAssetsByAreaParams({
    required this.areaId,
    this.forceRefresh = false,
  });

  final String areaId;
  final bool forceRefresh;
}

class GetAssetsByAreaUseCase
    implements UseCase<List<Asset>, GetAssetsByAreaParams> {
  const GetAssetsByAreaUseCase(this._repository);

  final AssetRepository _repository;

  @override
  Future<List<Asset>> call(GetAssetsByAreaParams params) {
    return _repository.getAssetsByArea(
      params.areaId,
      forceRefresh: params.forceRefresh,
    );
  }
}
