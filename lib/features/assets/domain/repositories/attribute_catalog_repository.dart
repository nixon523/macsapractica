import '../entities/asset_attribute_definition.dart';
import '../entities/brand.dart';
import '../entities/unit_of_measure.dart';

abstract class AttributeCatalogRepository {
  Future<List<UnitOfMeasure>> getUnitsOfMeasure({bool includeInactive = false});
  Future<UnitOfMeasure> createUnitOfMeasure({required String code, required String name});
  Future<UnitOfMeasure> updateUnitOfMeasure({
    required int id,
    required String code,
    required String name,
    bool isActive = true,
  });
  Future<void> deleteUnitOfMeasure(int id);

  Future<List<AssetAttributeDefinition>> getAttributeDefinitions({bool includeInactive = false});
  Future<AssetAttributeDefinition> createAttributeDefinition({
    required String name,
    String? description,
    int? defaultUnitId,
  });
  Future<AssetAttributeDefinition> updateAttributeDefinition({
    required int id,
    required String name,
    String? description,
    int? defaultUnitId,
    bool isActive = true,
  });
  Future<void> deleteAttributeDefinition(int id);

  Future<List<Brand>> getBrands({bool includeInactive = false});
  Future<Brand> createBrand({required String name, String? description});
  Future<Brand> updateBrand({
    required int id,
    required String name,
    String? description,
    bool isActive = true,
  });
  Future<void> deleteBrand(int id);
}
