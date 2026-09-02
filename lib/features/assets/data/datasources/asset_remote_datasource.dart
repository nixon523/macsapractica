import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/asset.dart';
import '../models/asset_model.dart';

/// DataSource remoto de Activos contra la API REST (SQL Server).
class AssetRemoteDataSource {
  const AssetRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Asset>> getAssetsByArea(String areaId) async {
    final response = await _apiClient.get(ApiEndpoints.assetsByArea(areaId));
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => AssetModel.fromJson(json))
          .where((asset) =>
              asset.parentAssetId == null && asset.status != AssetStatus.deleted)
          .toList();
    }
    return [];
  }

  Future<List<Asset>> getAllAssetsByArea(String areaId) async {
    final response = await _apiClient.get(
      ApiEndpoints.assetsByArea(areaId),
      queryParameters: {'all': 'true'},
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => AssetModel.fromJson(json))
          .where((asset) => asset.status != AssetStatus.deleted)
          .toList();
    }
    return [];
  }

  Future<List<Asset>> getAssetsByParent({
    String? parentAssetCode,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.assets,
      queryParameters: {
        if (parentAssetCode != null) 'parent': parentAssetCode,
        if (parentAssetCode != null) 'parentAssetCode': parentAssetCode,
      },
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => AssetModel.fromJson(json))
          .where((asset) =>
              asset.status != AssetStatus.deleted &&
              (parentAssetCode == null ||
                  asset.parentAssetId == parentAssetCode ||
                  asset.parentAssetId?.toLowerCase() ==
                      parentAssetCode.toLowerCase()))
          .toList();
    }
    return [];
  }

  Future<List<Asset>> searchAssets({
    required String areaId,
    List<String> tokens = const [],
    AssetStatus? status,
  }) async {
    final query = tokens.join(' ');

    // Si no hay tokens, obtener todos los activos del área
    // en vez de llamar al endpoint de búsqueda que requiere mínimo 2 caracteres
    if (query.trim().isEmpty) {
      final allAssets = await getAllAssetsByArea(areaId);
      if (status != null) {
        return allAssets.where((a) => a.status == status).toList();
      }
      return allAssets;
    }

    final response = await _apiClient.get(
      ApiEndpoints.assetSearch,
      queryParameters: {
        'q': query,
        if (areaId.isNotEmpty) 'areaId': areaId,
        if (status != null) 'status': status.name,
      },
    );
    if (response is List) {
      var assets = response
          .whereType<Map<String, dynamic>>()
          .map((json) => AssetModel.fromJson(json))
          .where((asset) => asset.status != AssetStatus.deleted)
          .toList();

      if (areaId.isNotEmpty) {
        assets = assets.where((a) => a.areaId == areaId).toList();
      }

      // Aplicar filtro de estado localmente
      if (status != null) {
        assets = assets.where((a) => a.status == status).toList();
      }

      return assets;
    }
    return [];
  }

  Future<Asset?> findBySerial(String serial) async {
    try {
      final response =
          await _apiClient.get(ApiEndpoints.assetBySerial(serial.trim()));
      if (response is Map<String, dynamic>) {
        final model = AssetModel.fromJson(response);
        return model.status != AssetStatus.deleted ? model : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Asset> createAsset(
    Asset asset, {
    required String userId,
    required String userName,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.assets,
      body: {
        'name': asset.name,
        'brand': asset.brand,
        'model': asset.model,
        'areaId': asset.areaId,
        'stationId': asset.stationId,
        'level': asset.level.name,
        'parentAssetCode': asset.parentAssetId,
        'status': asset.status.name,
        'serial': asset.serial,
        'dynamicAttributes': asset.dynamicAttributes,
        'imageData': asset.imageData,
      },
    );

    String newCode = asset.id;
    if (response is Map<String, dynamic>) {
      newCode = (response['NewAssetCode'] ??
              response['newAssetCode'] ??
              response['assetCode'] ??
              newCode)
          .toString();
    }

    return AssetModel(
      id: newCode.isNotEmpty ? newCode : asset.id,
      name: asset.name,
      brand: asset.brand,
      model: asset.model,
      areaId: asset.areaId,
      stationId: asset.stationId,
      parentAssetId: asset.parentAssetId,
      level: asset.level,
      ancestors: asset.ancestors,
      status: asset.status,
      dynamicAttributes: asset.dynamicAttributes,
      imageData: asset.imageData,
      serial: asset.serial,
      statusHistory: asset.statusHistory,
      createdAt: DateTime.now(),
    );
  }

  Future<Asset> updateAsset(
    Asset asset, {
    required String userId,
    required String userName,
  }) async {
    await _apiClient.put(
      ApiEndpoints.assetByCode(asset.id),
      body: {
        'name': asset.name,
        'brand': asset.brand,
        'model': asset.model,
        'stationId': asset.stationId,
        'status': asset.status.name,
        'dynamicAttributes': asset.dynamicAttributes,
        'imageData': asset.imageData,
      },
    );
    return asset;
  }

  Future<void> transferAsset({
    required Asset sourceAsset,
    required String targetAreaId,
    required String newAssetId,
    required String userId,
    required String userName,
  }) async {
    await _apiClient.post(
      ApiEndpoints.transferAsset(sourceAsset.id),
      body: {
        'targetAreaId': targetAreaId,
      },
    );
  }

  Future<void> reactivateAsset({
    required Asset asset,
    required String userId,
    required String userName,
  }) async {
    await _apiClient.post(
      ApiEndpoints.reactivateAsset(asset.id),
    );
  }

  Future<void> toggleAssetActiveStatus({
    required String assetId,
    required AssetStatus newStatus,
    required String reason,
    required String userId,
    required String userName,
  }) async {
    await _apiClient.patch(
      ApiEndpoints.toggleAssetStatus(assetId),
      body: {
        'newStatus': newStatus.name,
        'reason': reason,
      },
    );
  }
}
