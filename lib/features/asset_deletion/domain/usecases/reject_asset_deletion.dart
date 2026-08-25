import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/asset_delete_request.dart';
import '../repositories/asset_delete_repository.dart';

class RejectAssetDeletionParams {
  const RejectAssetDeletionParams({
    required this.request,
    required this.rejectedByUserId,
    required this.rejectedByUserName,
    required this.rejectReason,
  });

  final AssetDeleteRequest request;
  final String rejectedByUserId;
  final String rejectedByUserName;
  final String rejectReason;
}

class RejectAssetDeletionUseCase implements UseCase<void, RejectAssetDeletionParams> {
  const RejectAssetDeletionUseCase(this._repository);

  final AssetDeleteRepository _repository;

  @override
  Future<void> call(RejectAssetDeletionParams params) {
    if (!params.request.isPending) {
      throw const ValidationFailure(
        message: 'La solicitud ya fue aprobada o rechazada.',
      );
    }

    if (params.rejectReason.trim().isEmpty) {
      throw const ValidationFailure(
        message: 'Debes indicar el motivo del rechazo.',
      );
    }

    return _repository.rejectRequest(
      request: params.request,
      rejectedByUserId: params.rejectedByUserId,
      rejectedByUserName: params.rejectedByUserName,
      rejectReason: params.rejectReason.trim(),
    );
  }
}
