import '../../domain/entities/asset_attribute_definition.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/unit_of_measure.dart';
import '../../domain/repositories/attribute_catalog_repository.dart';
import '../datasources/attribute_catalog_remote_datasource.dart';

class AttributeCatalogRepositoryImpl implements AttributeCatalogRepository {
  const AttributeCatalogRepositoryImpl({
    required AttributeCatalogRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final AttributeCatalogRemoteDataSource _remoteDataSource;

  @override
  Future<List<UnitOfMeasure>> getUnitsOfMeasure({bool includeInactive = false}) {
    return _remoteDataSource.getUnitsOfMeasure(includeInactive: includeInactive);
  }

  @override
  Future<UnitOfMeasure> createUnitOfMeasure({required String code, required String name}) {
    return _remoteDataSource.createUnitOfMeasure(code: code, name: name);
  }

  @override
  Future<UnitOfMeasure> updateUnitOfMeasure({
    required int id,
    required String code,
    required String name,
    bool isActive = true,
  }) {
    return _remoteDataSource.updateUnitOfMeasure(
      id: id,
      code: code,
      name: name,
      isActive: isActive,
    );
  }

  @override
  Future<void> deleteUnitOfMeasure(int id) {
    return _remoteDataSource.deleteUnitOfMeasure(id);
  }

  @override
  Future<List<AssetAttributeDefinition>> getAttributeDefinitions({
    bool includeInactive = false,
  }) {
    return _remoteDataSource.getAttributeDefinitions(includeInactive: includeInactive);
  }

  @override
  Future<AssetAttributeDefinition> createAttributeDefinition({
    required String name,
    String? description,
    int? defaultUnitId,
  }) {
    return _remoteDataSource.createAttributeDefinition(
      name: name,
      description: description,
      defaultUnitId: defaultUnitId,
    );
  }

  @override
  Future<AssetAttributeDefinition> updateAttributeDefinition({
    required int id,
    required String name,
    String? description,
    int? defaultUnitId,
    bool isActive = true,
  }) {
    return _remoteDataSource.updateAttributeDefinition(
      id: id,
      name: name,
      description: description,
      defaultUnitId: defaultUnitId,
      isActive: isActive,
    );
  }

  @override
  Future<void> deleteAttributeDefinition(int id) {
    return _remoteDataSource.deleteAttributeDefinition(id);
  }

  @override
  Future<List<Brand>> getBrands({bool includeInactive = false}) {
    return _remoteDataSource.getBrands(includeInactive: includeInactive);
  }

  @override
  Future<Brand> createBrand({required String name, String? description}) {
    return _remoteDataSource.createBrand(name: name, description: description);
  }

  @override
  Future<Brand> updateBrand({
    required int id,
    required String name,
    String? description,
    bool isActive = true,
  }) {
    return _remoteDataSource.updateBrand(
      id: id,
      name: name,
      description: description,
      isActive: isActive,
    );
  }

  @override
  Future<void> deleteBrand(int id) {
    return _remoteDataSource.deleteBrand(id);
  }
}
