import 'package:flutter/foundation.dart';

import '../../domain/entities/work_order.dart';
import '../../domain/usecases/get_all_work_orders.dart';
import '../../domain/usecases/get_work_orders.dart';

class WorkOrderListViewModel extends ChangeNotifier {
  WorkOrderListViewModel({
    required GetAllWorkOrdersUseCase getAllWorkOrdersUseCase,
    required GetWorkOrdersUseCase getWorkOrdersUseCase,
  })  : _getAllWorkOrdersUseCase = getAllWorkOrdersUseCase,
        _getWorkOrdersUseCase = getWorkOrdersUseCase;

  final GetAllWorkOrdersUseCase _getAllWorkOrdersUseCase;
  final GetWorkOrdersUseCase _getWorkOrdersUseCase;

  List<WorkOrder> _workOrders = [];
  List<WorkOrder> get workOrders => _workOrders;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Future<void> loadAll({
    WorkOrderStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _workOrders = await _getAllWorkOrdersUseCase(
        GetAllWorkOrdersParams(
          status: status,
          startDate: startDate,
          endDate: endDate,
        ),
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadForAsset(String assetId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _workOrders =
          await _getWorkOrdersUseCase(GetWorkOrdersParams(assetId));
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
