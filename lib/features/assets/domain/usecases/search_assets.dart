import '../../../../core/usecases/usecase.dart';
import '../entities/asset.dart';
import '../repositories/asset_repository.dart';

class SearchAssetsParams {
  const SearchAssetsParams({
    required this.areaId,
    this.tokens = const [],
    this.status,
  });

  final String areaId;
  final List<String> tokens;
  final AssetStatus? status;
}

class SearchAssetsUseCase implements UseCase<List<Asset>, SearchAssetsParams> {
  const SearchAssetsUseCase(this._repository);

  final AssetRepository _repository;

  @override
  Future<List<Asset>> call(SearchAssetsParams params) {
    return _repository.searchAssets(
      areaId: params.areaId,
      tokens: params.tokens,
      status: params.status,
    );
  }
}
