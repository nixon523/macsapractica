import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/asset_delete_request.dart';
import '../repositories/asset_delete_repository.dart';

class ApproveAssetDeletionParams {
  const ApproveAssetDeletionParams({
    required this.request,
    required this.approvedByUserId,
    required this.approvedByUserName,
    this.approveReason,
  });

  final AssetDeleteRequest request;
  final String approvedByUserId;
  final String approvedByUserName;
  final String? approveReason;
}

class ApproveAssetDeletionUseCase implements UseCase<void, ApproveAssetDeletionParams> {
  const ApproveAssetDeletionUseCase(this._repository);

  final AssetDeleteRepository _repository;

  @override
  Future<void> call(ApproveAssetDeletionParams params) {
    if (!params.request.isPending) {
      throw const ValidationFailure(
        message: 'La solicitud ya fue aprobada o rechazada.',
      );
    }

    return _repository.approveRequest(
      request: params.request,
      approvedByUserId: params.approvedByUserId,
      approvedByUserName: params.approvedByUserName,
      approveReason: params.approveReason,
    );
  }
}
