import 'package:flutter/foundation.dart';

import '../../domain/entities/asset.dart';
import '../../domain/usecases/transfer_asset_usecase.dart';

enum TransferStep { idle, transferring, success, error }

class AssetTransferViewModel extends ChangeNotifier {
  AssetTransferViewModel({required this.transferAssetUseCase});

  final TransferAssetUseCase transferAssetUseCase;

  TransferStep _step = TransferStep.idle;
  TransferStep get step => _step;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool get isTransferring => _step == TransferStep.transferring;

  Future<bool> transfer({
    required Asset sourceAsset,
    required String targetAreaId,
    required String newAssetId,
    required String userId,
    required String userName,
  }) async {
    _step = TransferStep.transferring;
    _errorMessage = '';
    notifyListeners();

    try {
      await transferAssetUseCase(
        TransferAssetParams(
          sourceAsset: sourceAsset,
          targetAreaId: targetAreaId,
          newAssetId: newAssetId,
          userId: userId,
          userName: userName,
        ),
      );
      _step = TransferStep.success;
      notifyListeners();
      return true;
    } catch (e) {
      _step = TransferStep.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _step = TransferStep.idle;
    _errorMessage = '';
    notifyListeners();
  }
}
