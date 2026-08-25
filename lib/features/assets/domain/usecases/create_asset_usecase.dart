import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/asset.dart';
import '../repositories/asset_repository.dart';

class CreateAssetParams {
  const CreateAssetParams(this.asset, {required this.userId, required this.userName});

  final Asset asset;
  final String userId;
  final String userName;
}

class CreateAssetUseCase implements UseCase<Asset, CreateAssetParams> {
  const CreateAssetUseCase(this._repository);

  final AssetRepository _repository;

  @override
  Future<Asset> call(CreateAssetParams params) {
    final asset = params.asset;
    if (asset.name.trim().isEmpty) {
      throw const ValidationFailure(message: 'El nombre del activo es obligatorio.');
    }
    if (asset.areaId.trim().isEmpty) {
      throw const ValidationFailure(message: 'El área del activo es obligatoria.');
    }
    return _repository.createAsset(
      asset,
      userId: params.userId,
      userName: params.userName,
    );
  }
}
