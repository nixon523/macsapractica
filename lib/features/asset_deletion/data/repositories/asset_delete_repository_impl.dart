import '../../../assets/data/datasources/asset_remote_datasource.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../domain/entities/asset_delete_request.dart';
import '../../domain/repositories/asset_delete_repository.dart';
import '../datasources/asset_delete_remote_datasource.dart';

class AssetDeleteRepositoryImpl implements AssetDeleteRepository {
  const AssetDeleteRepositoryImpl({
    required this.remoteDataSource,
    required this.assetRemoteDataSource,
  });

  final AssetDeleteRemoteDataSource remoteDataSource;
  final AssetRemoteDataSource assetRemoteDataSource;

  @override
  Future<AssetDeleteRequest> createRequest({
    required Asset asset,
    required String reason,
    required String userId,
    required String userName,
  }) {
    return remoteDataSource.createRequest(
      asset: asset,
      reason: reason,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<List<AssetDeleteRequest>> getPendingRequests({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return remoteDataSource.getPendingRequests(
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<List<AssetDeleteRequest>> getAllRequests({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return remoteDataSource.getAllRequests(
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<AssetDeleteRequest?> getPendingRequestByAsset(String assetId) {
    return remoteDataSource.getPendingRequestByAsset(assetId);
  }

  @override
  Future<void> approveRequest({
    required AssetDeleteRequest request,
    required String approvedByUserId,
    required String approvedByUserName,
    String? approveReason,
  }) {
    return remoteDataSource.approveRequest(
      request: request,
      approvedByUserId: approvedByUserId,
      approvedByUserName: approvedByUserName,
      approveReason: approveReason,
    );
  }

  @override
  Future<void> rejectRequest({
    required AssetDeleteRequest request,
    required String rejectedByUserId,
    required String rejectedByUserName,
    required String rejectReason,
  }) {
    return remoteDataSource.rejectRequest(
      request: request,
      rejectedByUserId: rejectedByUserId,
      rejectedByUserName: rejectedByUserName,
      rejectReason: rejectReason,
    );
  }
}
