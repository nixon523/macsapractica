import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/asset.dart';
import '../repositories/asset_repository.dart';

class TransferAssetParams {
  const TransferAssetParams({
    required this.sourceAsset,
    required this.targetAreaId,
    required this.newAssetId,
    required this.userId,
    required this.userName,
  });

  final Asset sourceAsset;
  final String targetAreaId;
  final String newAssetId;
  final String userId;
  final String userName;
}

class TransferAssetUseCase implements UseCase<void, TransferAssetParams> {
  const TransferAssetUseCase(this._repository);

  final AssetRepository _repository;

  @override
  Future<void> call(TransferAssetParams params) {
    final source = params.sourceAsset;

    // Regla de negocio: solo se pueden transferir equipos en estado ACTIVO.
    if (!source.isActive) {
      throw const ValidationFailure(
        message: 'Solo se pueden transferir equipos en estado ACTIVO.',
      );
    }

    // Solo se transfieren equipos raíz (nivel equipo): el destino se crea como
    // un duplicado del equipo con toda su jerarquía y un nuevo ID.
    if (source.level != AssetLevel.equipment) {
      throw const ValidationFailure(
        message: 'Solo se pueden transferir equipos de nivel EQUIPO.',
      );
    }

    if (params.targetAreaId.trim().isEmpty) {
      throw const ValidationFailure(message: 'El área destino es obligatoria.');
    }

    if (params.newAssetId.trim().isEmpty) {
      throw const ValidationFailure(message: 'El nuevo ID del activo es obligatorio.');
    }

    return _repository.transferAsset(
      sourceAsset: params.sourceAsset,
      targetAreaId: params.targetAreaId,
      newAssetId: params.newAssetId,
      userId: params.userId,
      userName: params.userName,
    );
  }
}
