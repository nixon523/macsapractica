import 'package:flutter/foundation.dart';
import '../../domain/entities/asset_template.dart';
import '../../domain/usecases/asset_template_usecases.dart';

class AssetTemplateViewModel extends ChangeNotifier {
  AssetTemplateViewModel({
    required GetAssetTemplatesUseCase getTemplatesUseCase,
    required SaveAssetTemplateUseCase saveTemplateUseCase,
    required InstantiateAssetTemplateUseCase instantiateTemplateUseCase,
    required DeleteAssetTemplateUseCase deleteTemplateUseCase,
  })  : _getTemplatesUseCase = getTemplatesUseCase,
        _saveTemplateUseCase = saveTemplateUseCase,
        _instantiateTemplateUseCase = instantiateTemplateUseCase,
        _deleteTemplateUseCase = deleteTemplateUseCase;

  final GetAssetTemplatesUseCase _getTemplatesUseCase;
  final SaveAssetTemplateUseCase _saveTemplateUseCase;
  final InstantiateAssetTemplateUseCase _instantiateTemplateUseCase;
  final DeleteAssetTemplateUseCase _deleteTemplateUseCase;

  List<AssetTemplate> _templates = [];
  bool _isLoading = false;
  String _errorMessage = '';

  List<AssetTemplate> get templates => _templates;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  Future<void> loadTemplates({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();
    }

    try {
      _templates = await _getTemplatesUseCase();
      _errorMessage = '';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveFromAsset({
    required String sourceAssetCode,
    required String name,
    String? description,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _saveTemplateUseCase(SaveAssetTemplateParams(
        sourceAssetCode: sourceAssetCode,
        name: name,
        description: description,
      ));
      await loadTemplates(silent: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<InstantiateAssetTemplateResult?> instantiate({
    required int templateId,
    required String targetAreaId,
    String? newRootName,
    String? newSerial,
    String? observations,
    bool copyAttributes = true,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final result = await _instantiateTemplateUseCase(
        InstantiateAssetTemplateParams(
          templateId: templateId,
          targetAreaId: targetAreaId,
          newRootName: newRootName,
          newSerial: newSerial,
          observations: observations,
          copyAttributes: copyAttributes,
        ),
      );
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTemplate(int id) async {
    try {
      await _deleteTemplateUseCase(id);
      _templates.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
