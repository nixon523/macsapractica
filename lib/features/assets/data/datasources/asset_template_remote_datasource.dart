import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/asset_template.dart';

class AssetTemplateRemoteDataSource {
  const AssetTemplateRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AssetTemplate>> getTemplates() async {
    final response = await _apiClient.get(ApiEndpoints.assetTemplates);
    final list = (response is List) ? response : (response['data'] as List? ?? []);
    return list
        .whereType<Map>()
        .map((e) => AssetTemplate.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AssetTemplate> getTemplateDetail(int id) async {
    final response = await _apiClient.get(ApiEndpoints.assetTemplateById(id));
    final data = (response is Map<String, dynamic>)
        ? (response['data'] is Map ? response['data'] : response)
        : <String, dynamic>{};
    return AssetTemplate.fromJson(Map<String, dynamic>.from(data));
  }

  Future<int> saveTemplateFromAsset({
    required String sourceAssetCode,
    required String name,
    String? description,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.saveAssetTemplate,
      body: {
        'sourceAssetCode': sourceAssetCode,
        'name': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    final data = (response is Map<String, dynamic>)
        ? (response['data'] is Map ? response['data'] : response)
        : <String, dynamic>{};
    return int.tryParse((data['PlantillaId'] ?? data['plantillaId'] ?? data['id'] ?? 0).toString()) ?? 0;
  }

  Future<Map<String, dynamic>> instantiateTemplate({
    required int templateId,
    required String targetAreaId,
    String? newRootName,
    String? newSerial,
    String? observations,
    bool copyAttributes = true,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.instantiateAssetTemplate(templateId),
      body: {
        'targetAreaId': targetAreaId,
        if (newRootName != null && newRootName.trim().isNotEmpty)
          'newRootName': newRootName.trim(),
        if (newSerial != null && newSerial.trim().isNotEmpty)
          'newSerial': newSerial.trim(),
        if (observations != null && observations.trim().isNotEmpty)
          'observations': observations.trim(),
        'copyAttributes': copyAttributes,
      },
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return <String, dynamic>{};
  }

  Future<void> deleteTemplate(int templateId) async {
    await _apiClient.delete(ApiEndpoints.assetTemplateById(templateId));
  }
}
