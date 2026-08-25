import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../assets/domain/entities/asset.dart';
import '../entities/asset_delete_request.dart';
import '../repositories/asset_delete_repository.dart';

class RequestAssetDeletionParams {
  const RequestAssetDeletionParams({
    required this.asset,
    required this.reason,
    required this.userId,
    required this.userName,
  });

  final Asset asset;
  final String reason;
  final String userId;
  final String userName;
}

class RequestAssetDeletionUseCase
    implements UseCase<AssetDeleteRequest, RequestAssetDeletionParams> {
  const RequestAssetDeletionUseCase(this._repository);

  final AssetDeleteRepository _repository;

  @override
  Future<AssetDeleteRequest> call(RequestAssetDeletionParams params) async {
    final reason = params.reason.trim();
    if (reason.isEmpty) {
      throw const ValidationFailure(
        message: 'Debes indicar un motivo para la solicitud de eliminación.',
      );
    }

    if (params.asset.status == AssetStatus.deleted) {
      throw const ValidationFailure(
        message: 'El activo ya está dado de baja.',
      );
    }

    final pending = await _repository.getPendingRequestByAsset(params.asset.id);
    if (pending != null) {
      throw const ValidationFailure(
        message: 'Este activo ya tiene una solicitud de eliminación pendiente.',
      );
    }

    return _repository.createRequest(
      asset: params.asset,
      reason: reason,
      userId: params.userId,
      userName: params.userName,
    );
  }
}
