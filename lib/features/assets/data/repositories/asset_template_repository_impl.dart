import '../../domain/entities/asset_template.dart';
import '../../domain/repositories/asset_template_repository.dart';
import '../datasources/asset_template_remote_datasource.dart';

class AssetTemplateRepositoryImpl implements AssetTemplateRepository {
  const AssetTemplateRepositoryImpl({
    required this.remoteDataSource,
  });

  final AssetTemplateRemoteDataSource remoteDataSource;

  @override
  Future<List<AssetTemplate>> getTemplates() {
    return remoteDataSource.getTemplates();
  }

  @override
  Future<AssetTemplate> getTemplateDetail(int id) {
    return remoteDataSource.getTemplateDetail(id);
  }

  @override
  Future<int> saveTemplateFromAsset({
    required String sourceAssetCode,
    required String name,
    String? description,
  }) {
    return remoteDataSource.saveTemplateFromAsset(
      sourceAssetCode: sourceAssetCode,
      name: name,
      description: description,
    );
  }

  @override
  Future<Map<String, dynamic>> instantiateTemplate({
    required int templateId,
    required String targetAreaId,
    String? newRootName,
    String? newSerial,
    String? observations,
    bool copyAttributes = true,
  }) {
    return remoteDataSource.instantiateTemplate(
      templateId: templateId,
      targetAreaId: targetAreaId,
      newRootName: newRootName,
      newSerial: newSerial,
      observations: observations,
      copyAttributes: copyAttributes,
    );
  }

  @override
  Future<void> deleteTemplate(int templateId) {
    return remoteDataSource.deleteTemplate(templateId);
  }
}
