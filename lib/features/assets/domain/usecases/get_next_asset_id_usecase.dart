import '../../../../core/usecases/usecase.dart';
import '../repositories/asset_repository.dart';

class GetNextAssetIdParams {
  const GetNextAssetIdParams({
    required this.areaId,
    this.parentAssetId,
  });

  final String areaId;
  final String? parentAssetId;
}

class GetNextAssetIdUseCase implements UseCase<String, GetNextAssetIdParams> {
  const GetNextAssetIdUseCase(this._repository);

  final AssetRepository _repository;

  @override
  Future<String> call(GetNextAssetIdParams params) {
    return _repository.getNextAssetId(
      areaId: params.areaId,
      parentAssetId: params.parentAssetId,
    );
  }
}
