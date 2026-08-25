import 'package:flutter/foundation.dart';

import '../../../assets/domain/entities/area.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/usecases/get_areas_usecase.dart';
import '../../../assets/domain/usecases/get_assets_by_area.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/breakdown_report.dart';
import '../../domain/usecases/create_breakdown_report.dart';

/// ViewModel del formulario "Reportar Avería": carga áreas y los activos de la
/// área seleccionada, y envía el reporte al repositorio.
class ReportBreakdownViewModel extends ChangeNotifier {
  ReportBreakdownViewModel({
    required GetAreasUseCase getAreasUseCase,
    required GetAssetsByAreaUseCase getAssetsByAreaUseCase,
    required CreateBreakdownReportUseCase createBreakdownReportUseCase,
  })  : _getAreasUseCase = getAreasUseCase,
        _getAssetsByAreaUseCase = getAssetsByAreaUseCase,
        _createBreakdownReportUseCase = createBreakdownReportUseCase;

  final GetAreasUseCase _getAreasUseCase;
  final GetAssetsByAreaUseCase _getAssetsByAreaUseCase;
  final CreateBreakdownReportUseCase _createBreakdownReportUseCase;

  List<Area> _areas = const [];
  List<Area> get areas => _areas;

  List<Asset> _assets = const [];
  List<Asset> get assets => _assets;

  String? _selectedAreaId;
  String? get selectedAreaId => _selectedAreaId;

  String? _selectedAssetId;
  String? get selectedAssetId => _selectedAssetId;

  String _description = '';
  String get description => _description;

  BreakdownSeverity _severity = BreakdownSeverity.medium;
  BreakdownSeverity get severity => _severity;

  bool _isLoadingAreas = false;
  bool get isLoadingAreas => _isLoadingAreas;

  bool _isLoadingAssets = false;
  bool get isLoadingAssets => _isLoadingAssets;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Future<void> loadAreas() async {
    _isLoadingAreas = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _areas = await _getAreasUseCase(const NoParams());
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingAreas = false;
      notifyListeners();
    }
  }

  Future<void> selectArea(String areaId) async {
    _selectedAreaId = areaId;
    _selectedAssetId = null;
    _assets = const [];
    _errorMessage = '';
    notifyListeners();

    _isLoadingAssets = true;
    notifyListeners();
    try {
      final loaded = await _getAssetsByAreaUseCase(
        GetAssetsByAreaParams(areaId: areaId, forceRefresh: true),
      );
      _assets = loaded
          .where(
            (a) =>
                a.status != AssetStatus.transferredDeactivated &&
                a.status != AssetStatus.deleted,
          )
          .toList();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingAssets = false;
      notifyListeners();
    }
  }

  void selectAsset(String? assetId) {
    _selectedAssetId = assetId;
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
    notifyListeners();
  }

  void setSeverity(BreakdownSeverity severity) {
    _severity = severity;
    notifyListeners();
  }

  Future<bool> submit({
    required String userId,
    required String userName,
  }) async {
    _errorMessage = '';

    final asset = _selectedAssetId == null
        ? null
        : _assets.where((a) => a.id == _selectedAssetId).firstOrNull;
    if (asset == null) {
      _errorMessage = 'Selecciona el activo con la avería.';
      notifyListeners();
      return false;
    }
    if (_description.trim().isEmpty) {
      _errorMessage = 'Describe la avería.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    notifyListeners();
    try {
      await _createBreakdownReportUseCase(
        CreateBreakdownReportParams(
          assetId: asset.id,
          assetName: asset.name,
          areaId: asset.areaId,
          description: _description.trim(),
          severity: _severity,
          reportedByUserId: userId,
          reportedByUserName: userName,
        ),
      );
      _reset();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _reset() {
    _selectedAreaId = null;
    _selectedAssetId = null;
    _assets = const [];
    _description = '';
    _severity = BreakdownSeverity.medium;
  }
}
