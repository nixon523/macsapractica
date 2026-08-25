import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/breakdown_report.dart';
import '../../domain/repositories/breakdown_report_repository.dart';

/// Resultado de un reporte del usuario: se generó OT o fue rechazado.
enum ReportOutcomeKind { workOrderGenerated, rejected }

class ReportOutcome {
  const ReportOutcome({required this.report, required this.kind});

  final BreakdownReport report;
  final ReportOutcomeKind kind;
}

/// Alerta en tiempo real sobre los reportes del usuario actual cuando un
/// reporte pasa de `reported` a `inWorkOrder` o a `rejected`.
class MyReportsNotificationsViewModel extends ChangeNotifier {
  MyReportsNotificationsViewModel({
    BreakdownReportRepository? repository,
    Duration pollInterval = const Duration(seconds: 10),
  })  : _repository = repository,
        _pollInterval = pollInterval;

  final BreakdownReportRepository? _repository;
  final Duration _pollInterval;

  Timer? _timer;
  String? _currentUserId;

  final Map<String, BreakdownReportStatus> _knownStatuses = {};
  final Set<String> _unreadReportIds = {};
  ReportOutcome? _latestOutcome;
  bool _initialized = false;

  int get pendingUnreadCount => _unreadReportIds.length;

  ReportOutcome? get latestOutcome => _latestOutcome;

  bool get isListening => _timer != null;

  /// Inicia la consulta de los reportes del usuario. No hace nada si ya está
  /// activa para el mismo usuario o si la instancia no tiene repositorio.
  void start(String userId) {
    if (_timer != null && _currentUserId == userId) return;
    stop();
    _currentUserId = userId;
    final repo = _repository;
    if (repo == null) return;

    _poll();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      final reports = await _repository?.getReportsByUser(userId) ?? [];
      processSnapshot(reports);
    } catch (error) {
      debugPrint('MyReportsNotificationsViewModel error: $error');
    }
  }

  /// Procesa un snapshot: detecta transiciones `reported → inWorkOrder` y
  /// `reported → rejected`.
  @visibleForTesting
  void processSnapshot(List<BreakdownReport> reports) {
    final isFirst = !_initialized;
    _initialized = true;

    if (isFirst) {
      _knownStatuses.clear();
      for (final report in reports) {
        _knownStatuses[report.id] = report.status;
      }
    } else {
      for (final report in reports) {
        final previous = _knownStatuses[report.id];
        _knownStatuses[report.id] = report.status;

        if (previous == BreakdownReportStatus.reported) {
          if (report.status == BreakdownReportStatus.inWorkOrder) {
            _unreadReportIds.add(report.id);
            if (_latestOutcome == null) {
              _latestOutcome = ReportOutcome(
                report: report,
                kind: ReportOutcomeKind.workOrderGenerated,
              );
            }
          } else if (report.status == BreakdownReportStatus.rejected) {
            _unreadReportIds.add(report.id);
            if (_latestOutcome == null) {
              _latestOutcome = ReportOutcome(
                report: report,
                kind: ReportOutcomeKind.rejected,
              );
            }
          }
        }
      }
    }

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

  /// Consume la notificación pendiente y devuelve el resultado que la originó.
  ReportOutcome? consumeLatestOutcome() {
    final outcome = _latestOutcome;
    _latestOutcome = null;
    return outcome;
  }

  /// Marca como leídos los resultados pendientes (al abrir "Mis Reportes").
  void markSectionSeen() {
    _unreadReportIds.clear();
    _notifySafely();
  }

  /// Detiene la escucha y reinicia el estado.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _currentUserId = null;
    _knownStatuses.clear();
    _unreadReportIds.clear();
    _latestOutcome = null;
    _initialized = false;
    _notifySafely();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
