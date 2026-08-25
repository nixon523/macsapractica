import '../../../assets/domain/entities/asset.dart';
import '../entities/asset_delete_request.dart';

abstract class AssetDeleteRepository {
  /// Crea una solicitud de eliminación para un activo. La implementación
  /// verifica que no exista una solicitud pendiente para el mismo activo y
  /// registra el evento en el Kardex.
  Future<AssetDeleteRequest> createRequest({
    required Asset asset,
    required String reason,
    required String userId,
    required String userName,
  });

  Future<List<AssetDeleteRequest>> getPendingRequests({
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<AssetDeleteRequest>> getAllRequests({
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<AssetDeleteRequest?> getPendingRequestByAsset(String assetId);

  /// Aprueba la solicitud: da de baja (`deleted`) al activo y a todo su
  /// subárbol, y registra el evento en el Kardex.
  Future<void> approveRequest({
    required AssetDeleteRequest request,
    required String approvedByUserId,
    required String approvedByUserName,
    String? approveReason,
  });

  /// Rechaza la solicitud y registra el evento en el Kardex.
  Future<void> rejectRequest({
    required AssetDeleteRequest request,
    required String rejectedByUserId,
    required String rejectedByUserName,
    required String rejectReason,
  });
}
