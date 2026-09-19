import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/work_order.dart';
import '../../domain/repositories/work_order_repository.dart';

/// Alerta en tiempo real de OTs pendientes o vencidas.
///
/// Polling REST periódico que detecta:
/// - OTs de **alta prioridad** nuevas (estado `pending`).
/// - OTs con `scheduledDate` ya vencida y que siguen abiertas.
/// - OTs que llevan abiertas más de N días sin completarse.
///
/// Expone [pendingHighPriorityCount], [overdueCount] y [latestAlert].
class WorkOrderAlertsViewModel extends ChangeNotifier {
  WorkOrderAlertsViewModel({
    WorkOrderRepository? repository,
    Duration pollInterval = const Duration(seconds: 10),
  })  : _repository = repository,
        _pollInterval = pollInterval;

  final WorkOrderRepository? _repository;
  final Duration _pollInterval;

  Timer? _timer;
  final Set<String> _knownOrderIds = {};
  bool _initialized = false;
  int _pendingHighPriorityCount = 0;
  int _overdueCount = 0;
  int _totalOpenCount = 0;
  WorkOrder? _latestAlert;

  /// OTs abiertas de alta prioridad.
  int get pendingHighPriorityCount => _pendingHighPriorityCount;

  /// OTs abiertas cuya fecha programada ya pasó.
  int get overdueCount => _overdueCount;

  /// Total de OTs abiertas (pending + inProgress).
  int get totalOpenCount => _totalOpenCount;

  /// Badge para el sidebar: total de OTs abiertas (pendientes y en progreso).
  int get badgeCount => _totalOpenCount;

  /// Alerta nueva sin consumir.
  WorkOrder? get latestAlert => _latestAlert;

  bool get isListening => _timer != null;

  /// Inicia el polling. No hace nada si ya está activo o sin repo.
  void start() {
    if (_timer != null) return;
    final repo = _repository;
    if (repo == null) return;

    _poll();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  /// Fuerza una consulta inmediata para refrescar el contador de OTs.
  Future<void> refresh() async {
    await _poll();
  }

  Future<void> _poll() async {
    try {
      final openOrders = await _repository?.getAllWorkOrders() ?? [];
      final open = openOrders
          .where((o) =>
              o.status == WorkOrderStatus.pending ||
              o.status == WorkOrderStatus.inProgress)
          .toList();
      processSnapshot(open);
    } catch (error) {
      debugPrint('WorkOrderAlertsViewModel error: $error');
    }
  }

  /// Detiene la escucha y reinicia el estado.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _knownOrderIds.clear();
    _initialized = false;
    _pendingHighPriorityCount = 0;
    _overdueCount = 0;
    _totalOpenCount = 0;
    _latestAlert = null;
    _notifySafely();
  }

  /// Actualiza contadores y detecta OTs nuevas de alta prioridad o vencidas.
  @visibleForTesting
  void processSnapshot(List<WorkOrder> orders) {
    final isFirst = !_initialized;
    _initialized = true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final ids = {for (final o in orders) o.id};

    if (isFirst) {
      _knownOrderIds
        ..clear()
        ..addAll(ids);
    } else {
      // Detecta OTs nuevas de alta prioridad
      final newHighPriority = orders
          .where(
            (o) =>
                !_knownOrderIds.contains(o.id) &&
                o.priority == WorkOrderPriority.high,
          )
          .toList();
      _knownOrderIds.addAll(ids);

      if (_latestAlert == null && newHighPriority.isNotEmpty) {
        _latestAlert = newHighPriority.first;
      }
    }

    // Conteo de alta prioridad abierta
    _pendingHighPriorityCount = orders
        .where((o) => o.priority == WorkOrderPriority.high)
        .length;

    // Conteo de OTs con fecha vencida (scheduledDate < hoy)
    _overdueCount = orders.where((o) {
      final scheduled = o.scheduledDate;
      if (scheduled == null) return false;
      final scheduledDay =
          DateTime(scheduled.year, scheduled.month, scheduled.day);
      return scheduledDay.isBefore(today);
    }).length;

    _totalOpenCount = orders.length;

    _notifySafely();
  }

  void _notifySafely() {
    try {
      final binding = WidgetsBinding.instance;
      if (binding.schedulerPhase != SchedulerPhase.idle) {
        binding.addPostFrameCallback((_) {
          notifyListeners();
        });
        return;
      }
    } catch (_) {
      // Entorno de pruebas sin binding inicializado
    }
    notifyListeners();
  }

  /// Consume la alerta pendiente y devuelve la OT que la originó.
  WorkOrder? consumeLatestAlert() {
    final order = _latestAlert;
    _latestAlert = null;
    return order;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
