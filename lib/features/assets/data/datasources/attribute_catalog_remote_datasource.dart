import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/asset_attribute_definition_model.dart';
import '../models/brand_model.dart';
import '../models/unit_of_measure_model.dart';

class AttributeCatalogRemoteDataSource {
  const AttributeCatalogRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  // --------------------------------------------------------------------------
  // Unidades de Medida
  // --------------------------------------------------------------------------
  Future<List<UnitOfMeasureModel>> getUnitsOfMeasure({bool includeInactive = false}) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.unitsOfMeasure}?includeInactive=$includeInactive',
    );
    final data = response as List<dynamic>;
    return data
        .map((e) => UnitOfMeasureModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UnitOfMeasureModel> createUnitOfMeasure({
    required String code,
    required String name,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.unitsOfMeasure,
      body: {'code': code, 'name': name},
    );
    return UnitOfMeasureModel.fromJson(response as Map<String, dynamic>);
  }

  Future<UnitOfMeasureModel> updateUnitOfMeasure({
    required int id,
    required String code,
    required String name,
    bool isActive = true,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.unitOfMeasureById(id),
      body: {'code': code, 'name': name, 'isActive': isActive},
    );
    return UnitOfMeasureModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteUnitOfMeasure(int id) async {
    await _apiClient.delete(ApiEndpoints.unitOfMeasureById(id));
  }

  // --------------------------------------------------------------------------
  // Atributos de Activos
  // --------------------------------------------------------------------------
  Future<List<AssetAttributeDefinitionModel>> getAttributeDefinitions({
    bool includeInactive = false,
  }) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.attributeCatalog}?includeInactive=$includeInactive',
    );
    final data = response as List<dynamic>;
    return data
        .map((e) => AssetAttributeDefinitionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AssetAttributeDefinitionModel> createAttributeDefinition({
    required String name,
    String? description,
    int? defaultUnitId,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.attributeCatalog,
      body: {
        'name': name,
        'description': description,
        'defaultUnitId': defaultUnitId,
      },
    );
    return AssetAttributeDefinitionModel.fromJson(response as Map<String, dynamic>);
  }

  Future<AssetAttributeDefinitionModel> updateAttributeDefinition({
    required int id,
    required String name,
    String? description,
    int? defaultUnitId,
    bool isActive = true,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.attributeCatalogById(id),
      body: {
        'name': name,
        'description': description,
        'defaultUnitId': defaultUnitId,
        'isActive': isActive,
      },
    );
    return AssetAttributeDefinitionModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteAttributeDefinition(int id) async {
    await _apiClient.delete(ApiEndpoints.attributeCatalogById(id));
  }

  // --------------------------------------------------------------------------
  // Marcas de Activos
  // --------------------------------------------------------------------------
  Future<List<BrandModel>> getBrands({bool includeInactive = false}) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.brands}?includeInactive=$includeInactive',
    );
    final data = response as List<dynamic>;
    return data
        .map((e) => BrandModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BrandModel> createBrand({
    required String name,
    String? description,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.brands,
      body: {'name': name, 'description': description},
    );
    return BrandModel.fromJson(response as Map<String, dynamic>);
  }

  Future<BrandModel> updateBrand({
    required int id,
    required String name,
    String? description,
    bool isActive = true,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.brandById(id),
      body: {'name': name, 'description': description, 'isActive': isActive},
    );
    return BrandModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteBrand(int id) async {
    await _apiClient.delete(ApiEndpoints.brandById(id));
  }
}
