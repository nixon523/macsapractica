import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/asset.dart';
import '../repositories/asset_repository.dart';

class ReactivateAssetParams {
  const ReactivateAssetParams({
    required this.asset,
    required this.userId,
    required this.userName,
  });

  final Asset asset;
  final String userId;
  final String userName;
}

class ReactivateAssetUseCase implements UseCase<void, ReactivateAssetParams> {
  const ReactivateAssetUseCase(this._repository);

  final AssetRepository _repository;

  @override
  Future<void> call(ReactivateAssetParams params) {
    final asset = params.asset;

    // Regla de negocio: solo se reactivan activos deshabilitados por una
    // transferencia. Un activo activo o inactivo se gestiona vía edición.
    if (asset.status != AssetStatus.transferredDeactivated) {
      throw const ValidationFailure(
        message: 'Solo se pueden reactivar activos transferidos/deshabilitados.',
      );
    }

    return _repository.reactivateAsset(
      asset: params.asset,
      userId: params.userId,
      userName: params.userName,
    );
  }
}
