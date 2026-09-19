import 'package:flutter/foundation.dart';

import '../../../../app/di/get_it.dart';
import '../../../../core/error/failures.dart';
import '../../../breakdown_reports/presentation/viewmodels/breakdown_alerts_viewmodel.dart';
import '../../../breakdown_reports/presentation/viewmodels/my_reports_notifications_viewmodel.dart';
import '../../domain/entities/work_order.dart';
import '../../domain/usecases/update_work_order_details.dart';
import '../../domain/usecases/update_work_order_status.dart';
import 'work_order_alerts_viewmodel.dart';

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

      // Refrescar inmediatamente los contadores de alertas y badges
      try {
        if (getIt.isRegistered<WorkOrderAlertsViewModel>()) {
          getIt<WorkOrderAlertsViewModel>().refresh();
        }
        if (getIt.isRegistered<BreakdownAlertsViewModel>()) {
          getIt<BreakdownAlertsViewModel>().refresh();
        }
        if (getIt.isRegistered<MyReportsNotificationsViewModel>()) {
          getIt<MyReportsNotificationsViewModel>().refresh();
        }
      } catch (_) {}

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
