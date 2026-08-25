import '../../domain/entities/asset.dart';

/// DataSource local para caché en memoria de activos por área.
class AssetLocalDataSource {
  final Map<String, List<Asset>> _cache = {};

  Future<List<Asset>> getAssetsByArea(String areaId) async {
    return _cache[areaId] ?? const [];
  }

  void saveAssetsForArea(String areaId, List<Asset> assets) {
    _cache[areaId] = assets;
  }

  void clear() {
    _cache.clear();
  }
}
