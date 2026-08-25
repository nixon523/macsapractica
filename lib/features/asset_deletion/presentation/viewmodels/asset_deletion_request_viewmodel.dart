import 'package:flutter/foundation.dart';

import '../../../assets/domain/entities/asset.dart';
import '../../domain/entities/asset_delete_request.dart';
import '../../domain/usecases/get_deletion_request_by_asset.dart';
import '../../domain/usecases/request_asset_deletion.dart';

enum DeletionRequestViewState { initial, loading, success, error }

/// ViewModel usado en el detalle del activo: consulta la solicitud pendiente
/// del activo y permite crear una nueva solicitud de eliminación.
class AssetDeletionRequestViewModel extends ChangeNotifier {
  AssetDeletionRequestViewModel({
    required GetDeletionRequestByAssetUseCase getDeletionRequestByAssetUseCase,
    required RequestAssetDeletionUseCase requestAssetDeletionUseCase,
  })  : _getDeletionRequestByAssetUseCase = getDeletionRequestByAssetUseCase,
        _requestAssetDeletionUseCase = requestAssetDeletionUseCase;

  final GetDeletionRequestByAssetUseCase _getDeletionRequestByAssetUseCase;
  final RequestAssetDeletionUseCase _requestAssetDeletionUseCase;

  DeletionRequestViewState _viewState = DeletionRequestViewState.initial;
  DeletionRequestViewState get viewState => _viewState;

  AssetDeleteRequest? _pendingRequest;
  AssetDeleteRequest? get pendingRequest => _pendingRequest;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool _isRequesting = false;
  bool get isRequesting => _isRequesting;

  Future<void> loadPending(String assetId) async {
    _viewState = DeletionRequestViewState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _pendingRequest =
          await _getDeletionRequestByAssetUseCase(
              GetDeletionRequestByAssetParams(assetId));
      _viewState = DeletionRequestViewState.success;
    } catch (e) {
      _errorMessage = e.toString();
      _viewState = DeletionRequestViewState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> request({
    required Asset asset,
    required String reason,
    required String userId,
    required String userName,
  }) async {
    _isRequesting = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _pendingRequest = await _requestAssetDeletionUseCase(
        RequestAssetDeletionParams(
          asset: asset,
          reason: reason,
          userId: userId,
          userName: userName,
        ),
      );
      _isRequesting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isRequesting = false;
      notifyListeners();
      return false;
    }
  }
}
