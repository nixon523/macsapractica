import 'package:flutter/foundation.dart';

import '../../domain/entities/operation_report.dart';
import '../../domain/usecases/actualizar_es_equipo_proceso.dart';
import '../../domain/usecases/listar_equipos_proceso.dart';
import '../../domain/usecases/obtener_metricas_operacion.dart';
import '../../domain/usecases/obtener_reporte_semana.dart';
import '../../domain/usecases/registrar_reporte_operacion.dart';

/// Modo de visualización del reporte de disponibilidad operativa.
enum OperationReportViewMode { weekly, monthly }

/// Resumen consolidado mensual de disponibilidad por equipo.
class MonthlyEquipmentSummary {
  const MonthlyEquipmentSummary({
    required this.codigoActivo,
    required this.nombreActivo,
    required this.horasTotalesJornada,
    required this.horasOperacion,
    required this.horasParoFalla,
    required this.horasParoMantPrev,
    required this.horasParoMantCorr,
    required this.horasParoPlanificado,
    required this.horasParoExterno,
    required this.reportesRegistrados,
    required this.diasDelMes,
    required this.disponibilidadPct,
    required this.weeklyDisponibilidades,
  });

  final String codigoActivo;
  final String nombreActivo;
  final double horasTotalesJornada;
  final double horasOperacion;
  final double horasParoFalla;
  final double horasParoMantPrev;
  final double horasParoMantCorr;
  final double horasParoPlanificado;
  final double horasParoExterno;
  final int reportesRegistrados;
  final int diasDelMes;
  final double disponibilidadPct;
  final List<double> weeklyDisponibilidades;
}

class OperationReportViewModel extends ChangeNotifier {
  OperationReportViewModel({
    required RegistrarReporteOperacion registrar,
    required ObtenerReporteSemana obtenerSemana,
    required ObtenerMetricasOperacion obtenerMetricas,
    required ListarEquiposProceso listarEquipos,
    required ActualizarEsEquipoProceso actualizarEquipo,
  })  : _registrar = registrar,
        _obtenerSemana = obtenerSemana,
        _obtenerMetricas = obtenerMetricas,
        _listarEquipos = listarEquipos,
        _actualizarEquipo = actualizarEquipo;

  final RegistrarReporteOperacion _registrar;
  final ObtenerReporteSemana _obtenerSemana;
  final ObtenerMetricasOperacion _obtenerMetricas;
  final ListarEquiposProceso _listarEquipos;
  final ActualizarEsEquipoProceso _actualizarEquipo;

  // --- Modo de vista ---
  OperationReportViewMode _viewMode = OperationReportViewMode.weekly;
  OperationReportViewMode get viewMode => _viewMode;

  // --- Estado de equipos de proceso ---
  List<EquipoProceso> _equipos = [];
  List<EquipoProceso> get equipos => _equipos;
  bool _loadingEquipos = false;
  bool get loadingEquipos => _loadingEquipos;
  String? _equiposError;
  String? get equiposError => _equiposError;

  // --- Estado del reporte semanal ---
  /// Mapa: `codigoActivo -> List<OperationReport>` (7 entradas, una por día)
  Map<String, List<OperationReport>> _weeklyReports = {};
  Map<String, List<OperationReport>> get weeklyReports => _weeklyReports;
  bool _loadingWeekly = false;
  bool get loadingWeekly => _loadingWeekly;
  String? _weeklyError;
  String? get weeklyError => _weeklyError;

  /// Semana actualmente en vista (lunes de la semana)
  DateTime _currentMonday = _lastMonday(DateTime.now());
  DateTime get currentMonday => _currentMonday;

  // --- Estado del reporte mensual ---
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime get selectedMonth => _selectedMonth;

  List<MonthlyEquipmentSummary> _monthlySummaries = [];
  List<MonthlyEquipmentSummary> get monthlySummaries => _monthlySummaries;
  bool _loadingMonthly = false;
  bool get loadingMonthly => _loadingMonthly;
  String? _monthlyError;
  String? get monthlyError => _monthlyError;

  String? _selectedAreaId;
  String? get selectedAreaId => _selectedAreaId;

  // --- Estado de métricas ---
  OperationMetrics? _metrics;
  OperationMetrics? get metrics => _metrics;
  bool _loadingMetrics = false;
  bool get loadingMetrics => _loadingMetrics;
  String? _metricsError;
  String? get metricsError => _metricsError;

  // --- Estado de guardado de un día ---
  bool _saving = false;
  bool get saving => _saving;
  String? _saveError;
  String? get saveError => _saveError;
  bool _savedOk = false;
  bool get savedOk => _savedOk;

  // -------------------------------------------------------------------------
  // Cambio de modo de vista
  // -------------------------------------------------------------------------
  void setViewMode(OperationReportViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
    if (_selectedAreaId != null) {
      if (mode == OperationReportViewMode.weekly) {
        cargarSemana(_selectedAreaId!);
      } else {
        cargarMes(_selectedAreaId!);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Equipos de proceso
  // -------------------------------------------------------------------------
  Future<void> cargarEquipos({String? areaId}) async {
    _loadingEquipos = true;
    _equiposError = null;
    notifyListeners();
    try {
      _equipos = await _listarEquipos(areaId);
    } catch (e) {
      _equiposError = e.toString();
    } finally {
      _loadingEquipos = false;
      notifyListeners();
    }
  }

  Future<void> toggleEquipoProceso(
    String codigoActivo, {
    required bool esEquipoProceso,
  }) async {
    try {
      await _actualizarEquipo(
        codigoActivo,
        esEquipoProceso: esEquipoProceso,
      );
    } catch (e) {
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // Navegación y carga temporal
  // -------------------------------------------------------------------------
  void seleccionarArea(String areaId) {
    _selectedAreaId = areaId;
    _weeklyReports = {};
    _monthlySummaries = [];
    notifyListeners();
    if (_viewMode == OperationReportViewMode.weekly) {
      cargarSemana(areaId);
    } else {
      cargarMes(areaId);
    }
  }

  void irHoy() {
    final now = DateTime.now();
    _currentMonday = _lastMonday(now);
    _selectedMonth = DateTime(now.year, now.month, 1);
    notifyListeners();
    if (_selectedAreaId != null) {
      if (_viewMode == OperationReportViewMode.weekly) {
        cargarSemana(_selectedAreaId!);
      } else {
        cargarMes(_selectedAreaId!);
      }
    }
  }

  void seleccionarFecha(DateTime fecha) {
    _currentMonday = _lastMonday(fecha);
    _selectedMonth = DateTime(fecha.year, fecha.month, 1);
    notifyListeners();
    if (_selectedAreaId != null) {
      if (_viewMode == OperationReportViewMode.weekly) {
        cargarSemana(_selectedAreaId!);
      } else {
        cargarMes(_selectedAreaId!);
      }
    }
  }

  void irSemanaAnterior() {
    _currentMonday = _currentMonday.subtract(const Duration(days: 7));
    _weeklyReports = {};
    notifyListeners();
    if (_selectedAreaId != null) cargarSemana(_selectedAreaId!);
  }

  void irSemanaSiguiente() {
    final candidato = _currentMonday.add(const Duration(days: 7));
    _currentMonday = candidato;
    _weeklyReports = {};
    notifyListeners();
    if (_selectedAreaId != null) cargarSemana(_selectedAreaId!);
  }

  void irMesAnterior() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    _monthlySummaries = [];
    notifyListeners();
    if (_selectedAreaId != null) cargarMes(_selectedAreaId!);
  }

  void irMesSiguiente() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    _monthlySummaries = [];
    notifyListeners();
    if (_selectedAreaId != null) cargarMes(_selectedAreaId!);
  }

  void seleccionarMes(DateTime mes) {
    _selectedMonth = DateTime(mes.year, mes.month, 1);
    _monthlySummaries = [];
    notifyListeners();
    if (_selectedAreaId != null) cargarMes(_selectedAreaId!);
  }

  // -------------------------------------------------------------------------
  // Carga semanal
  // -------------------------------------------------------------------------
  Future<void> cargarSemana(String areaId) async {
    _selectedAreaId = areaId;
    _loadingWeekly = true;
    _weeklyError = null;
    notifyListeners();
    try {
      final rows = await _obtenerSemana(areaId, _currentMonday);
      final Map<String, List<OperationReport>> map = {};
      for (final r in rows) {
        map.putIfAbsent(r.codigoActivo, () => []).add(r);
      }
      _weeklyReports = map;
    } catch (e) {
      _weeklyError = e.toString();
    } finally {
      _loadingWeekly = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Carga mensual consolidada
  // -------------------------------------------------------------------------
  Future<void> cargarMes(String areaId, [DateTime? mes]) async {
    _selectedAreaId = areaId;
    final targetMonth = mes ?? _selectedMonth;
    _selectedMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    _loadingMonthly = true;
    _monthlyError = null;
    notifyListeners();

    try {
      final firstDay = DateTime(targetMonth.year, targetMonth.month, 1);
      final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0);
      final totalDaysInMonth = lastDay.day;

      DateTime currentWeekMonday = _lastMonday(firstDay);
      final List<DateTime> mondaysToFetch = [];
      while (currentWeekMonday.isBefore(lastDay) || _sameDay(currentWeekMonday, lastDay)) {
        mondaysToFetch.add(currentWeekMonday);
        currentWeekMonday = currentWeekMonday.add(const Duration(days: 7));
      }

      final Map<String, List<OperationReport>> reportsByAsset = {};
      final Map<String, String> assetNames = {};

      for (final monday in mondaysToFetch) {
        final weekRows = await _obtenerSemana(areaId, monday);
        for (final r in weekRows) {
          assetNames[r.codigoActivo] = r.nombreActivo;
          // Solo incluir días que pertenecen efectivamente al mes seleccionado
          if (r.fechaOperacion.year == targetMonth.year &&
              r.fechaOperacion.month == targetMonth.month) {
            reportsByAsset.putIfAbsent(r.codigoActivo, () => []).add(r);
          }
        }
      }

      final List<MonthlyEquipmentSummary> summaries = [];
      for (final entry in assetNames.entries) {
        final assetCode = entry.key;
        final assetName = entry.value;
        final reports = reportsByAsset[assetCode] ?? [];

        double sumJornada = 0;
        double sumOperacion = 0;
        double sumFalla = 0;
        double sumMP = 0;
        double sumMC = 0;
        double sumPlan = 0;
        double sumExt = 0;
        int registeredDays = 0;

        for (final r in reports) {
          if (r.tieneReporte) {
            registeredDays++;
            sumJornada += r.horasTotalesJornada;
            sumOperacion += r.horasOperacion;
            sumFalla += r.horasParoFalla;
            sumMP += r.horasParoMantPrev;
            sumMC += r.horasParoMantCorr;
            sumPlan += r.horasParoPlanificado;
            sumExt += r.horasParoExterno;
          }
        }

        final dispPct = sumJornada > 0
            ? (sumOperacion / sumJornada * 100).clamp(0.0, 100.0)
            : 0.0;

        summaries.add(
          MonthlyEquipmentSummary(
            codigoActivo: assetCode,
            nombreActivo: assetName,
            horasTotalesJornada: sumJornada,
            horasOperacion: sumOperacion,
            horasParoFalla: sumFalla,
            horasParoMantPrev: sumMP,
            horasParoMantCorr: sumMC,
            horasParoPlanificado: sumPlan,
            horasParoExterno: sumExt,
            reportesRegistrados: registeredDays,
            diasDelMes: totalDaysInMonth,
            disponibilidadPct: dispPct,
            weeklyDisponibilidades: const [],
          ),
        );
      }

      _monthlySummaries = summaries;
    } catch (e) {
      _monthlyError = e.toString();
    } finally {
      _loadingMonthly = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Registrar/actualizar reporte de un día
  // -------------------------------------------------------------------------
  Future<bool> guardarDia({
    required String codigoActivo,
    required DateTime fecha,
    required double horasTotalesJornada,
    required double horasOperacion,
    required double horasParoFalla,
    required double horasParoMantPrev,
    required double horasParoMantCorr,
    required double horasParoPlanificado,
    required double horasParoExterno,
    String? observaciones,
  }) async {
    _saving = true;
    _saveError = null;
    _savedOk = false;
    notifyListeners();
    try {
      final saved = await _registrar(
        codigoActivo: codigoActivo,
        fechaOperacion: fecha,
        horasTotalesJornada: horasTotalesJornada,
        horasOperacion: horasOperacion,
        horasParoFalla: horasParoFalla,
        horasParoMantPrev: horasParoMantPrev,
        horasParoMantCorr: horasParoMantCorr,
        horasParoPlanificado: horasParoPlanificado,
        horasParoExterno: horasParoExterno,
        observaciones: observaciones,
      );
      // Actualizar en la lista local
      final lista = _weeklyReports[codigoActivo];
      if (lista != null) {
        final idx = lista.indexWhere(
          (r) => _sameDay(r.fechaOperacion, fecha),
        );
        if (idx >= 0) {
          lista[idx] = saved;
        } else {
          lista.add(saved);
        }
        _weeklyReports[codigoActivo] = List<OperationReport>.from(lista);
      }
      _savedOk = true;
      return true;
    } catch (e) {
      _saveError = e.toString();
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Métricas
  // -------------------------------------------------------------------------
  Future<void> cargarMetricas(
    String codigoActivo, {
    required DateTime desde,
    required DateTime hasta,
  }) async {
    _loadingMetrics = true;
    _metricsError = null;
    notifyListeners();
    try {
      _metrics = await _obtenerMetricas(codigoActivo, desde, hasta);
    } catch (e) {
      _metricsError = e.toString();
    } finally {
      _loadingMetrics = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  static DateTime _lastMonday(DateTime date) {
    final weekday = date.weekday; // 1=lunes...7=domingo
    return date.subtract(Duration(days: weekday - 1));
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String get weekLabel {
    final end = _currentMonday.add(const Duration(days: 6));
    return '${_fmt(_currentMonday)} – ${_fmt(end)}';
  }

  String get monthLabel {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${meses[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2,"0")}/${d.month.toString().padLeft(2,"0")}/${d.year}';
}
