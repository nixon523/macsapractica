import 'package:flutter/foundation.dart';

import '../../domain/entities/asset.dart';
import '../../domain/repositories/asset_repository.dart';
import '../../domain/usecases/get_assets_by_parent.dart';
import '../../domain/usecases/reactivate_asset_usecase.dart';

enum DetailViewState { initial, loading, success, error }

class AssetDetailViewModel extends ChangeNotifier {
  AssetDetailViewModel({
    required GetAssetsByParentUseCase getAssetsByParentUseCase,
    required ReactivateAssetUseCase reactivateAssetUseCase,
    required AssetRepository assetRepository,
  })  : _getAssetsByParentUseCase = getAssetsByParentUseCase,
        _reactivateAssetUseCase = reactivateAssetUseCase,
        _assetRepository = assetRepository;

  final GetAssetsByParentUseCase _getAssetsByParentUseCase;
  final ReactivateAssetUseCase _reactivateAssetUseCase;
  final AssetRepository _assetRepository;

  DetailViewState _viewState = DetailViewState.initial;
  DetailViewState get viewState => _viewState;

  List<Asset> _children = const [];
  List<Asset> get children => _children;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool get isLoading => _viewState == DetailViewState.loading;

  bool _isReactivating = false;
  bool get isReactivating => _isReactivating;

  String? _reactivationError;
  String? get reactivationError => _reactivationError;

  Future<void> loadChildren({
    required String areaId,
    required String parentAssetId,
  }) async {
    _viewState = DetailViewState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _children = await _getAssetsByParentUseCase(
        GetAssetsByParentParams(
          areaId: areaId,
          parentAssetId: parentAssetId,
        ),
      );
      _viewState = DetailViewState.success;
    } catch (e) {
      _errorMessage = e.toString();
      _viewState = DetailViewState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> reactivate({
    required Asset asset,
    required String userId,
    required String userName,
  }) async {
    _isReactivating = true;
    _reactivationError = null;
    notifyListeners();

    try {
      await _reactivateAssetUseCase(
        ReactivateAssetParams(
          asset: asset,
          userId: userId,
          userName: userName,
        ),
      );
      _isReactivating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _reactivationError = e.toString();
      _isReactivating = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleActiveStatus({
    required String assetId,
    required AssetStatus newStatus,
    required String reason,
    required String userId,
    required String userName,
  }) async {
    _viewState = DetailViewState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      await _assetRepository.toggleAssetActiveStatus(
        assetId: assetId,
        newStatus: newStatus,
        reason: reason,
        userId: userId,
        userName: userName,
      );
      _viewState = DetailViewState.success;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _viewState = DetailViewState.error;
      notifyListeners();
      return false;
    }
  }
}
