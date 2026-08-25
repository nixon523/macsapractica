import 'package:flutter/foundation.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/asset_delete_request.dart';
import '../../domain/usecases/approve_asset_deletion.dart';
import '../../domain/usecases/get_deletion_requests.dart';
import '../../domain/usecases/reject_asset_deletion.dart';

enum DeletionRequestsViewState { initial, loading, success, error }

/// ViewModel de la bandeja de solicitudes del Gerente de Operaciones: lista
/// todas las solicitudes y resuelve (aprueba/rechaza) las pendientes.
class DeletionRequestsViewModel extends ChangeNotifier {
  DeletionRequestsViewModel({
    required GetDeletionRequestsUseCase getDeletionRequestsUseCase,
    required ApproveAssetDeletionUseCase approveAssetDeletionUseCase,
    required RejectAssetDeletionUseCase rejectAssetDeletionUseCase,
  })  : _getDeletionRequestsUseCase = getDeletionRequestsUseCase,
        _approveAssetDeletionUseCase = approveAssetDeletionUseCase,
        _rejectAssetDeletionUseCase = rejectAssetDeletionUseCase;

  final GetDeletionRequestsUseCase _getDeletionRequestsUseCase;
  final ApproveAssetDeletionUseCase _approveAssetDeletionUseCase;
  final RejectAssetDeletionUseCase _rejectAssetDeletionUseCase;

  DeletionRequestsViewState _viewState = DeletionRequestsViewState.initial;
  DeletionRequestsViewState get viewState => _viewState;

  List<AssetDeleteRequest> _requests = const [];
  List<AssetDeleteRequest> get requests => _requests;

  List<AssetDeleteRequest> get pendingRequests =>
      _requests.where((r) => r.isPending).toList();

  List<AssetDeleteRequest> get resolvedRequests =>
      _requests.where((r) => !r.isPending).toList();

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  Future<void> load({DateTime? startDate, DateTime? endDate}) async {
    _viewState = DeletionRequestsViewState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _requests = await _getDeletionRequestsUseCase(
        GetDeletionRequestsParams(startDate: startDate, endDate: endDate),
      );
      _viewState = DeletionRequestsViewState.success;
    } catch (e) {
      _errorMessage = e.toString();
      _viewState = DeletionRequestsViewState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> approve({
    required AssetDeleteRequest request,
    required String approvedByUserId,
    required String approvedByUserName,
    String? approveReason,
  }) async {
    return _resolve(() => _approveAssetDeletionUseCase(
          ApproveAssetDeletionParams(
            request: request,
            approvedByUserId: approvedByUserId,
            approvedByUserName: approvedByUserName,
            approveReason: approveReason,
          ),
        ));
  }

  Future<bool> reject({
    required AssetDeleteRequest request,
    required String rejectedByUserId,
    required String rejectedByUserName,
    required String rejectReason,
  }) async {
    return _resolve(() => _rejectAssetDeletionUseCase(
          RejectAssetDeletionParams(
            request: request,
            rejectedByUserId: rejectedByUserId,
            rejectedByUserName: rejectedByUserName,
            rejectReason: rejectReason,
          ),
        ));
  }

  Future<bool> _resolve(Future<void> Function() action) async {
    _isProcessing = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await action();
      await load();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
