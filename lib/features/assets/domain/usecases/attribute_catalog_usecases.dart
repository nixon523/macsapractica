import '../entities/asset_attribute_definition.dart';
import '../entities/brand.dart';
import '../entities/unit_of_measure.dart';
import '../repositories/attribute_catalog_repository.dart';

class GetAttributeCatalogUseCase {
  const GetAttributeCatalogUseCase(this._repository);
  final AttributeCatalogRepository _repository;

  Future<List<AssetAttributeDefinition>> call({bool includeInactive = false}) {
    return _repository.getAttributeDefinitions(includeInactive: includeInactive);
  }
}

class SaveAttributeDefinitionUseCase {
  const SaveAttributeDefinitionUseCase(this._repository);
  final AttributeCatalogRepository _repository;

  Future<AssetAttributeDefinition> call({
    int? id,
    required String name,
    String? description,
    int? defaultUnitId,
    bool isActive = true,
  }) {
    if (id == null || id == 0) {
      return _repository.createAttributeDefinition(
        name: name,
        description: description,
        defaultUnitId: defaultUnitId,
      );
    }
    return _repository.updateAttributeDefinition(
      id: id,
      name: name,
      description: description,
      defaultUnitId: defaultUnitId,
      isActive: isActive,
    );
  }
}

class DeleteAttributeDefinitionUseCase {
  const DeleteAttributeDefinitionUseCase(this._repository);
  final AttributeCatalogRepository _repository;

  Future<void> call(int id) {
    return _repository.deleteAttributeDefinition(id);
  }
}

class GetUnitsOfMeasureUseCase {
  const GetUnitsOfMeasureUseCase(this._repository);
  final AttributeCatalogRepository _repository;

  Future<List<UnitOfMeasure>> call({bool includeInactive = false}) {
    return _repository.getUnitsOfMeasure(includeInactive: includeInactive);
  }
}

class SaveUnitOfMeasureUseCase {
  const SaveUnitOfMeasureUseCase(this._repository);
  final AttributeCatalogRepository _repository;

  Future<UnitOfMeasure> call({
    int? id,
    required String code,
    required String name,
    bool isActive = true,
  }) {
    if (id == null || id == 0) {
      return _repository.createUnitOfMeasure(code: code, name: name);
    }
    return _repository.updateUnitOfMeasure(
      id: id,
      code: code,
      name: name,
      isActive: isActive,
    );
  }
}

class DeleteUnitOfMeasureUseCase {
  const DeleteUnitOfMeasureUseCase(this._repository);
  final AttributeCatalogRepository _repository;

  Future<void> call(int id) {
    return _repository.deleteUnitOfMeasure(id);
  }
}

class GetBrandsUseCase {
  const GetBrandsUseCase(this._repository);
  final AttributeCatalogRepository _repository;

  Future<List<Brand>> call({bool includeInactive = false}) {
    return _repository.getBrands(includeInactive: includeInactive);
  }
}

class SaveBrandUseCase {
  const SaveBrandUseCase(this._repository);
  final AttributeCatalogRepository _repository;

  Future<Brand> call({
    int? id,
    required String name,
    String? description,
    bool isActive = true,
  }) {
    if (id == null || id == 0) {
      return _repository.createBrand(name: name, description: description);
    }
    return _repository.updateBrand(
      id: id,
      name: name,
      description: description,
      isActive: isActive,
    );
  }
}

class DeleteBrandUseCase {
  const DeleteBrandUseCase(this._repository);
  final AttributeCatalogRepository _repository;

  Future<void> call(int id) {
    return _repository.deleteBrand(id);
  }
}
