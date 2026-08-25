import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../domain/entities/asset_delete_request.dart';
import '../models/asset_delete_request_model.dart';

/// DataSource remoto de Solicitudes de Baja contra la API REST (SQL Server).
class AssetDeleteRemoteDataSource {
  const AssetDeleteRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AssetDeleteRequest>> getPendingRequests({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.pendingDeletionRequests,
      queryParameters: {
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      },
    );

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => AssetDeleteRequestModel.fromJson(json))
          .toList();
    }
    return [];
  }

  Future<List<AssetDeleteRequest>> getAllRequests({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.deletionRequests,
      queryParameters: {
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      },
    );

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => AssetDeleteRequestModel.fromJson(json))
          .toList();
    }
    return [];
  }

  Future<AssetDeleteRequest?> getPendingRequestByAsset(String assetId) async {
    final response =
        await _apiClient.get(ApiEndpoints.pendingDeletionByAsset(assetId));
    if (response is List && response.isNotEmpty) {
      return AssetDeleteRequestModel.fromJson(
          response.first as Map<String, dynamic>);
    } else if (response is Map<String, dynamic>) {
      return AssetDeleteRequestModel.fromJson(response);
    }
    return null;
  }

  Future<AssetDeleteRequest> createRequest({
    required Asset asset,
    required String reason,
    required String userId,
    required String userName,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.deletionRequests,
      body: {
        'assetCode': asset.id,
        'reason': reason,
      },
    );

    String newId = '';
    if (response is Map<String, dynamic>) {
      newId = (response['RequestId'] ??
              response['requestId'] ??
              response['id'] ??
              '')
          .toString();
    }

    return AssetDeleteRequest(
      id: newId,
      assetId: asset.id,
      assetName: asset.name,
      areaId: asset.areaId,
      status: DeletionRequestStatus.pending,
      reason: reason,
      requestedByUserId: userId,
      requestedByUserName: userName,
      requestedAt: DateTime.now(),
      subtreeCount: 1,
    );
  }

  Future<void> approveRequest({
    required AssetDeleteRequest request,
    required String approvedByUserId,
    required String approvedByUserName,
    String? approveReason,
  }) async {
    await _apiClient.post(
      ApiEndpoints.approveDeletionRequest(request.id),
      body: {
        if (approveReason != null && approveReason.isNotEmpty)
          'reason': approveReason,
      },
    );
  }

  Future<void> rejectRequest({
    required AssetDeleteRequest request,
    required String rejectedByUserId,
    required String rejectedByUserName,
    required String rejectReason,
  }) async {
    await _apiClient.post(
      ApiEndpoints.rejectDeletionRequest(request.id),
      body: {
        'reason': rejectReason,
      },
    );
  }
}
