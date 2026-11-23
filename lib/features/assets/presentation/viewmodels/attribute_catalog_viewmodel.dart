import 'package:flutter/foundation.dart';
import '../../../../app/di/get_it.dart';
import '../../domain/entities/asset_attribute_definition.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/unit_of_measure.dart';
import '../../domain/usecases/attribute_catalog_usecases.dart';

class AttributeCatalogViewModel extends ChangeNotifier {
  AttributeCatalogViewModel({
    required GetAttributeCatalogUseCase getAttributeCatalogUseCase,
    required SaveAttributeDefinitionUseCase saveAttributeDefinitionUseCase,
    required DeleteAttributeDefinitionUseCase deleteAttributeDefinitionUseCase,
    required GetUnitsOfMeasureUseCase getUnitsOfMeasureUseCase,
    required SaveUnitOfMeasureUseCase saveUnitOfMeasureUseCase,
    required DeleteUnitOfMeasureUseCase deleteUnitOfMeasureUseCase,
    GetBrandsUseCase? getBrandsUseCase,
    SaveBrandUseCase? saveBrandUseCase,
    DeleteBrandUseCase? deleteBrandUseCase,
  })  : _getAttributeCatalogUseCase = getAttributeCatalogUseCase,
        _saveAttributeDefinitionUseCase = saveAttributeDefinitionUseCase,
        _deleteAttributeDefinitionUseCase = deleteAttributeDefinitionUseCase,
        _getUnitsOfMeasureUseCase = getUnitsOfMeasureUseCase,
        _saveUnitOfMeasureUseCase = saveUnitOfMeasureUseCase,
        _deleteUnitOfMeasureUseCase = deleteUnitOfMeasureUseCase,
        _getBrandsUseCase = getBrandsUseCase ??
            (getIt.isRegistered<GetBrandsUseCase>()
                ? getIt<GetBrandsUseCase>()
                : null),
        _saveBrandUseCase = saveBrandUseCase ??
            (getIt.isRegistered<SaveBrandUseCase>()
                ? getIt<SaveBrandUseCase>()
                : null),
        _deleteBrandUseCase = deleteBrandUseCase ??
            (getIt.isRegistered<DeleteBrandUseCase>()
                ? getIt<DeleteBrandUseCase>()
                : null);

  final GetAttributeCatalogUseCase _getAttributeCatalogUseCase;
  final SaveAttributeDefinitionUseCase _saveAttributeDefinitionUseCase;
  final DeleteAttributeDefinitionUseCase _deleteAttributeDefinitionUseCase;
  final GetUnitsOfMeasureUseCase _getUnitsOfMeasureUseCase;
  final SaveUnitOfMeasureUseCase _saveUnitOfMeasureUseCase;
  final DeleteUnitOfMeasureUseCase _deleteUnitOfMeasureUseCase;
  final GetBrandsUseCase? _getBrandsUseCase;
  final SaveBrandUseCase? _saveBrandUseCase;
  final DeleteBrandUseCase? _deleteBrandUseCase;

  List<AssetAttributeDefinition> _attributes = [];
  List<UnitOfMeasure> _units = [];
  List<Brand> _brands = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AssetAttributeDefinition> get attributes => _attributes;
  List<UnitOfMeasure> get units => _units;
  List<Brand> get brands => _brands;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadAll({bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (!forceRefresh &&
        _attributes.isNotEmpty &&
        _units.isNotEmpty &&
        _brands.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final futures = <Future<dynamic>>[
        _getAttributeCatalogUseCase(),
        _getUnitsOfMeasureUseCase(),
        if (_getBrandsUseCase != null)
          _getBrandsUseCase.call()
        else
          Future.value(<Brand>[]),
      ];

      final results = await Future.wait(futures);

      _attributes = results[0] as List<AssetAttributeDefinition>;
      _units = results[1] as List<UnitOfMeasure>;
      _brands = results[2] as List<Brand>;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveBrand({
    int? id,
    required String name,
    String? description,
    bool isActive = true,
  }) async {
    if (_saveBrandUseCase == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _saveBrandUseCase(
        id: id,
        name: name,
        description: description,
        isActive: isActive,
      );
      if (_getBrandsUseCase != null) {
        _brands = await _getBrandsUseCase.call();
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBrand(int id) async {
    if (_deleteBrandUseCase == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _deleteBrandUseCase(id);
      if (_getBrandsUseCase != null) {
        _brands = await _getBrandsUseCase.call();
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveAttribute({
    int? id,
    required String name,
    String? description,
    int? defaultUnitId,
    bool isActive = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _saveAttributeDefinitionUseCase(
        id: id,
        name: name,
        description: description,
        defaultUnitId: defaultUnitId,
        isActive: isActive,
      );
      _attributes = await _getAttributeCatalogUseCase();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAttribute(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _deleteAttributeDefinitionUseCase(id);
      _attributes = await _getAttributeCatalogUseCase();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveUnit({
    int? id,
    required String code,
    required String name,
    bool isActive = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _saveUnitOfMeasureUseCase(
        id: id,
        code: code,
        name: name,
        isActive: isActive,
      );
      _units = await _getUnitsOfMeasureUseCase();
      // También refrescamos atributos por si alguna unidad por defecto cambió de nombre/código
      _attributes = await _getAttributeCatalogUseCase();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUnit(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _deleteUnitOfMeasureUseCase(id);
      _units = await _getUnitsOfMeasureUseCase();
      _attributes = await _getAttributeCatalogUseCase();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
