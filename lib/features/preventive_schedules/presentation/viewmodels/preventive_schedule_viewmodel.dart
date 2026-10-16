import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../../../work_orders/domain/entities/work_order.dart';
import '../../../work_orders/domain/repositories/work_order_repository.dart';
import '../../domain/entities/preventive_schedule.dart';
import '../../domain/repositories/preventive_schedule_repository.dart';
import '../states/preventive_schedule_state.dart';

class PreventiveScheduleViewModel extends ChangeNotifier {
  PreventiveScheduleViewModel({
    required PreventiveScheduleRepository repository,
    WorkOrderRepository? workOrderRepository,
  })  : _repository = repository,
        _workOrderRepository = workOrderRepository;

  final PreventiveScheduleRepository _repository;
  final WorkOrderRepository? _workOrderRepository;

  PreventiveScheduleState _state = const PreventiveScheduleState();
  PreventiveScheduleState get state => _state;
  List<PreventiveSchedule> get schedules => _state.schedules;

  List<WorkOrder> _openWorkOrders = const [];
  List<WorkOrder> get openWorkOrders => _openWorkOrders;

  WorkOrder? getActiveWorkOrder(String scheduleId) {
    return _openWorkOrders.where((wo) {
      final matchesPlan = wo.preventiveScheduleId == scheduleId;
      final isOpen = wo.status == WorkOrderStatus.pending ||
          wo.status == WorkOrderStatus.inProgress;
      return matchesPlan && isOpen;
    }).firstOrNull;
  }

  bool hasActiveWorkOrder(String scheduleId) =>
      getActiveWorkOrder(scheduleId) != null;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String _successMessage = '';
  String get successMessage => _successMessage;

  int get urgentAndOverdueCount {
    return _state.schedules
        .where((s) => s.status == ScheduleStatus.active && (s.isOverdue || s.daysRemaining <= 2))
        .length;
  }

  Future<void> loadSchedules({
    String? areaId,
    ScheduleStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _state = const PreventiveScheduleState(viewState: ViewState.loading);
    _errorMessage = '';
    notifyListeners();

    try {
      final schedules = await _repository.getAllSchedules(
        areaId: areaId,
        status: status,
        startDate: startDate,
        endDate: endDate,
      );
      if (_workOrderRepository != null) {
        try {
          _openWorkOrders = await _workOrderRepository.getOpenWorkOrders();
        } catch (_) {}
      }
      _state = PreventiveScheduleState(
        viewState: ViewState.success,
        schedules: schedules,
      );
    } catch (e) {
      final msg = e is Failure ? e.message : e.toString();
      _state = PreventiveScheduleState(
        viewState: ViewState.error,
        errorMessage: msg,
      );
    } finally {
      notifyListeners();
    }
  }

  // Alias for backward compatibility if needed
  Future<void> fetchAllActiveSchedules({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      loadSchedules(status: ScheduleStatus.active, startDate: startDate, endDate: endDate);

  Future<bool> createSchedule({
    required PreventiveSchedule schedule,
    required String userId,
    required String userName,
  }) async {
    _isSaving = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      final created = await _repository.createSchedule(
        schedule: schedule,
        userId: userId,
        userName: userName,
      );
      _successMessage = 'Plan preventivo ${created.id} creado con éxito.';
      await loadSchedules();
      return true;
    } catch (e) {
      _errorMessage = e is Failure ? e.message : e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> amendSchedule({
    required String scheduleId,
    required String amendmentDocNumber,
    required String authorizedByManager,
    required String amendmentReason,
    required PreventiveSchedule updatedSchedule,
    required String userId,
    required String userName,
  }) async {
    _isSaving = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      await _repository.amendSchedule(
        scheduleId: scheduleId,
        amendmentDocNumber: amendmentDocNumber,
        authorizedByManager: authorizedByManager,
        amendmentReason: amendmentReason,
        updatedSchedule: updatedSchedule,
        userId: userId,
        userName: userName,
      );
      _successMessage = 'Plan preventivo $scheduleId modificado bajo autorización gerencial ($amendmentDocNumber).';
      await loadSchedules();
      return true;
    } catch (e) {
      _errorMessage = e is Failure ? e.message : e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> toggleScheduleStatus({
    required String scheduleId,
    required ScheduleStatus status,
    required String amendmentDocNumber,
    required String authorizedByManager,
    required String reason,
    required String userId,
    required String userName,
  }) async {
    _isSaving = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _repository.toggleScheduleStatus(
        scheduleId: scheduleId,
        status: status,
        amendmentDocNumber: amendmentDocNumber,
        authorizedByManager: authorizedByManager,
        reason: reason,
        userId: userId,
        userName: userName,
      );
      _successMessage = 'Estado del plan actualizado a ${status.label} bajo autorización gerencial ($amendmentDocNumber).';
      await loadSchedules();
      return true;
    } catch (e) {
      _errorMessage = e is Failure ? e.message : e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> generateMonthlyWorkOrder(
    String scheduleId, {
    int? year,
    int? month,
  }) async {
    final activeOt = getActiveWorkOrder(scheduleId);
    if (activeOt != null) {
      _errorMessage =
          'Ya existe la Orden de Trabajo activa ${activeOt.id} para este plan preventivo.';
      notifyListeners();
      return null;
    }

    _isSaving = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      final otId = await _repository.generateMonthlyWorkOrder(
        scheduleId: scheduleId,
        year: year,
        month: month,
      );
      _successMessage = 'Orden de Trabajo consolidada $otId generada con éxito.';
      await loadSchedules();
      return otId;
    } catch (e) {
      _errorMessage = e is Failure ? e.message : e.toString();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<List<String>> generateBatchMonthlyWorkOrders({
    required int year,
    required int month,
    String? areaId,
    required String userId,
    required String userName,
  }) async {
    _isSaving = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      final ots = await _repository.generateBatchMonthlyWorkOrders(
        year: year,
        month: month,
        areaId: areaId,
        userId: userId,
        userName: userName,
      );
      if (ots.isNotEmpty) {
        _successMessage = 'Se generaron ${ots.length} Órdenes de Trabajo preventivas exitosamente.';
      } else {
        _errorMessage = 'No se encontraron actividades preventivas pendientes para el periodo seleccionado.';
      }
      await loadSchedules();
      return ots;
    } catch (e) {
      _errorMessage = e is Failure ? e.message : e.toString();
      return [];
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
