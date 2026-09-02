import '../../domain/entities/asset.dart';
import '../../domain/repositories/asset_repository.dart';
import '../datasources/asset_local_datasource.dart';
import '../datasources/asset_remote_datasource.dart';

class AssetRepositoryImpl implements AssetRepository {
  const AssetRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  final AssetRemoteDataSource remoteDataSource;
  final AssetLocalDataSource localDataSource;

  @override
  Future<List<Asset>> getAssetsByArea(
    String areaId, {
    bool forceRefresh = false,
  }) async {
    final assets = await remoteDataSource.getAssetsByArea(areaId);
    localDataSource.saveAssetsForArea(areaId, assets);
    return assets;
  }

  @override
  Future<List<Asset>> getAllAssetsByArea(
    String areaId, {
    bool forceRefresh = false,
  }) async {
    return remoteDataSource.getAllAssetsByArea(areaId);
  }

  @override
  Future<List<Asset>> getAssetsByParent({
    required String areaId,
    String? parentAssetId,
    bool forceRefresh = false,
  }) async {
    return remoteDataSource.getAssetsByParent(
      parentAssetCode: parentAssetId,
    );
  }

  @override
  Future<List<Asset>> searchAssets({
    required String areaId,
    List<String> tokens = const [],
    AssetStatus? status,
  }) {
    return remoteDataSource.searchAssets(
      areaId: areaId,
      tokens: tokens,
      status: status,
    );
  }

  @override
  Future<String> getNextAssetId({
    required String areaId,
    String? parentAssetId,
  }) async {
    if (parentAssetId == null) {
      final assets = await remoteDataSource.getAssetsByArea(areaId);
      int maxNum = 0;
      for (final a in assets) {
        final parts = a.id.split('-');
        if (parts.length >= 2) {
          final num = int.tryParse(parts[1]);
          if (num != null && num > maxNum) maxNum = num;
        }
      }
      return '$areaId-${(maxNum + 1).toString().padLeft(3, '0')}';
    }

    final children = await remoteDataSource.getAssetsByParent(
      parentAssetCode: parentAssetId,
    );
    int maxChild = 0;
    for (final c in children) {
      final parts = c.id.split('-');
      if (parts.isNotEmpty) {
        final last = int.tryParse(parts.last);
        if (last != null && last > maxChild) maxChild = last;
      }
    }
    return '$parentAssetId-${(maxChild + 1).toString().padLeft(2, '0')}';
  }

  @override
  Future<Asset> createAsset(
    Asset asset, {
    required String userId,
    required String userName,
  }) {
    return remoteDataSource.createAsset(
      asset,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<Asset> updateAsset(
    Asset asset, {
    required String userId,
    required String userName,
  }) {
    return remoteDataSource.updateAsset(
      asset,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<void> transferAsset({
    required Asset sourceAsset,
    required String targetAreaId,
    required String newAssetId,
    required String userId,
    required String userName,
  }) {
    return remoteDataSource.transferAsset(
      sourceAsset: sourceAsset,
      targetAreaId: targetAreaId,
      newAssetId: newAssetId,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<void> reactivateAsset({
    required Asset asset,
    required String userId,
    required String userName,
  }) {
    return remoteDataSource.reactivateAsset(
      asset: asset,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<void> toggleAssetActiveStatus({
    required String assetId,
    required AssetStatus newStatus,
    required String reason,
    required String userId,
    required String userName,
  }) {
    return remoteDataSource.toggleAssetActiveStatus(
      assetId: assetId,
      newStatus: newStatus,
      reason: reason,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<Asset?> findAssetBySerial(String serial) {
    return remoteDataSource.findBySerial(serial);
  }
}
