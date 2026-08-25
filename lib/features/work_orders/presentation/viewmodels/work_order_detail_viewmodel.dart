import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/work_order.dart';
import '../../domain/usecases/update_work_order_details.dart';
import '../../domain/usecases/update_work_order_status.dart';

class WorkOrderDetailViewModel extends ChangeNotifier {
  WorkOrderDetailViewModel({
    required UpdateWorkOrderStatusUseCase updateStatusUseCase,
    required UpdateWorkOrderDetailsUseCase updateDetailsUseCase,
  })  : _updateStatusUseCase = updateStatusUseCase,
        _updateDetailsUseCase = updateDetailsUseCase;

  final UpdateWorkOrderStatusUseCase _updateStatusUseCase;
  final UpdateWorkOrderDetailsUseCase _updateDetailsUseCase;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Future<bool> updateStatus({
    required WorkOrder order,
    required WorkOrderStatus status,
    required String userId,
    required String userName,
  }) async {
    _isProcessing = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _updateStatusUseCase(
        UpdateWorkOrderStatusParams(
          workOrderId: order.id,
          status: status,
          userId: userId,
          userName: userName,
        ),
      );
      return true;
    } catch (e) {
      _errorMessage = e is Failure ? e.message : e.toString();
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<bool> updateDetails({
    required WorkOrder updatedOrder,
    required String userId,
    required String userName,
  }) async {
    _isProcessing = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _updateDetailsUseCase(
        UpdateWorkOrderDetailsParams(
          workOrder: updatedOrder,
          userId: userId,
          userName: userName,
        ),
      );
      return true;
    } catch (e) {
      _errorMessage = e is Failure ? e.message : e.toString();
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
