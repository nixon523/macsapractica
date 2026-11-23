import '../entities/asset_template.dart';

abstract class AssetTemplateRepository {
  Future<List<AssetTemplate>> getTemplates();

  Future<AssetTemplate> getTemplateDetail(int id);

  Future<int> saveTemplateFromAsset({
    required String sourceAssetCode,
    required String name,
    String? description,
  });

  Future<Map<String, dynamic>> instantiateTemplate({
    required int templateId,
    required String targetAreaId,
    String? newRootName,
    String? newSerial,
    String? observations,
    bool copyAttributes = true,
  });

  Future<void> deleteTemplate(int templateId);
}
