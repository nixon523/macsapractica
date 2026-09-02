import '../entities/asset.dart';

abstract class AssetRepository {
  Future<List<Asset>> getAssetsByArea(
    String areaId, {
    bool forceRefresh = false,
  });

  /// Devuelve TODOS los activos del área (padres e hijos, excluyendo eliminados).
  /// Usado para la vista de árbol jerárquico completo.
  Future<List<Asset>> getAllAssetsByArea(
    String areaId, {
    bool forceRefresh = false,
  });

  /// Devuelve los activos hijos de un padre (o los equipos raíz del área
  /// cuando [parentAssetId] es null).
  Future<List<Asset>> getAssetsByParent({
    required String areaId,
    String? parentAssetId,
    bool forceRefresh = false,
  });

  /// Búsqueda server-side sobre el área usando índices compuestos.
  /// [tokens] son términos "contiene" (arrayContainsAny); [status] es un
  /// filtro opcional de estado (null = todos).
  Future<List<Asset>> searchAssets({
    required String areaId,
    List<String> tokens = const [],
    AssetStatus? status,
  });

  /// Genera el siguiente ID relacional (ej. `A3-002` o `A3-002-01`)
  /// sin persistir el activo. Usado para mostrar una vista previa.
  Future<String> getNextAssetId({
    required String areaId,
    String? parentAssetId,
  });

  Future<Asset> createAsset(
    Asset asset, {
    required String userId,
    required String userName,
  });

  Future<Asset> updateAsset(
    Asset asset, {
    required String userId,
    required String userName,
  });

  Future<void> transferAsset({
    required Asset sourceAsset,
    required String targetAreaId,
    required String newAssetId,
    required String userId,
    required String userName,
  });

  /// Reactiva un activo transferido/deshabilitado junto con todo su subárbol
  /// (estado ACTIVO) y limpia el vínculo con el duplicado.
  Future<void> reactivateAsset({
    required Asset asset,
    required String userId,
    required String userName,
  });

  /// Inactiva (fuera de servicio) o Reactiva un activo en su área actual,
  /// actualizando la bitácora cronológica de períodos de estado y registrando en Kardex.
  Future<void> toggleAssetActiveStatus({
    required String assetId,
    required AssetStatus newStatus,
    required String reason,
    required String userId,
    required String userName,
  });

  /// Busca globalmente (en todas las áreas) un equipo con el [serial] dado.
  ///
  /// Solo retorna activos no dados de baja. Retorna `null` si el serial
  /// no existe o si solo existe en activos eliminados.
  Future<Asset?> findAssetBySerial(String serial);
}
