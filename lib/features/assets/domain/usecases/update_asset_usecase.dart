import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/asset.dart';
import '../repositories/asset_repository.dart';

class UpdateAssetParams {
  const UpdateAssetParams(this.asset, {required this.userId, required this.userName});

  final Asset asset;
  final String userId;
  final String userName;
}

class UpdateAssetUseCase implements UseCase<Asset, UpdateAssetParams> {
  const UpdateAssetUseCase(this._repository);

  final AssetRepository _repository;

  @override
  Future<Asset> call(UpdateAssetParams params) {
    final asset = params.asset;
    if (asset.name.trim().isEmpty) {
      throw const ValidationFailure(
        message: 'El nombre del activo es obligatorio.',
      );
    }
    return _repository.updateAsset(
      asset,
      userId: params.userId,
      userName: params.userName,
    );
  }
}
