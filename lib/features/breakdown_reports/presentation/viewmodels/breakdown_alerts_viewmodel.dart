import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/breakdown_report.dart';
import '../../domain/repositories/breakdown_report_repository.dart';

/// Notificaciones y alertas de averías pendientes (estado `reported`).
///
/// Consulta periódicamente el servidor mediante polling REST (o actualiza
/// su estado mediante [processSnapshot]) para alertar al usuario.
///
/// - [pendingCount]: averías aún sin atender (estado `reported`).
/// - [latestNewReport]: avería nueva detectada tras el snapshot inicial.
class BreakdownAlertsViewModel extends ChangeNotifier {
  BreakdownAlertsViewModel({
    BreakdownReportRepository? repository,
    Duration pollInterval = const Duration(seconds: 10),
  })  : _repository = repository,
        _pollInterval = pollInterval;

  final BreakdownReportRepository? _repository;
  final Duration _pollInterval;

  Timer? _timer;
  final Set<String> _knownReportIds = {};
  bool _initialized = false;
  int _pendingCount = 0;
  BreakdownReport? _latestNewReport;

  /// Averías pendientes de revisión (estado `reported`).
  int get pendingCount => _pendingCount;

  /// Reporte recién llegado, si hay una alerta sin consumir.
  BreakdownReport? get latestNewReport => _latestNewReport;

  bool get isListening => _timer != null;

  /// Inicia la consulta periódica en tiempo real. No hace nada si ya está activa
  /// o si la instancia no tiene repositorio (caso de tests unitarios).
  void start() {
    if (_timer != null) return;
    final repo = _repository;
    if (repo == null) return;

    _poll();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final openReports = await _repository?.getOpenReports() ?? [];
      final reported = openReports
          .where((r) => r.status == BreakdownReportStatus.reported)
          .toList();
      processSnapshot(reported);
    } catch (error) {
      debugPrint('BreakdownAlertsViewModel error: $error');
    }
  }

  /// Detiene la escucha y reinicia el estado.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _knownReportIds.clear();
    _initialized = false;
    _pendingCount = 0;
    _latestNewReport = null;
    _notifySafely();
  }

  /// Actualiza el contador y detecta reportes nuevos.
  ///
  /// El primer snapshot solo siembra los IDs conocidos (no dispara alerta);
  /// los siguientes, si aparece un id nuevo, lo exponen en [latestNewReport].
  @visibleForTesting
  void processSnapshot(List<BreakdownReport> reports) {
    final isFirst = !_initialized;
    _initialized = true;

    final ids = {for (final report in reports) report.id};
    if (isFirst) {
      _knownReportIds
        ..clear()
        ..addAll(ids);
    } else {
      final newReports =
          reports.where((r) => !_knownReportIds.contains(r.id)).toList();
      _knownReportIds.addAll(ids);
      if (_latestNewReport == null && newReports.isNotEmpty) {
        _latestNewReport = newReports.first;
      }
    }

    _pendingCount = reports.length;
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

  /// Consume la alerta pendiente y devuelve el reporte que la originó.
  BreakdownReport? consumeLatestReport() {
    final report = _latestNewReport;
    _latestNewReport = null;
    return report;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
