import 'package:flutter/foundation.dart';

import '../../../breakdown_reports/domain/entities/breakdown_report.dart';
import '../../../breakdown_reports/domain/usecases/get_all_breakdown_reports.dart';
import '../../../preventive_schedules/domain/entities/preventive_schedule.dart';
import '../../../preventive_schedules/domain/repositories/preventive_schedule_repository.dart';
import '../../../work_orders/domain/entities/work_order.dart';
import '../../../work_orders/domain/usecases/get_all_work_orders.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/entities/cost_center_maintenance_stats.dart';
import '../../domain/entities/dashboard_stats.dart';

/// Periodo temporal para el gráfico interactivo de balance operativo.
enum DashboardChartPeriod {
  semana('Semana'),
  mes('Mes'),
  ano('Año'),
  historico('Histórico');

  const DashboardChartPeriod(this.label);
  final String label;
}

/// Punto de datos para una columna/intervalo del gráfico interactivo.
class DashboardChartPoint {
  const DashboardChartPoint({
    required this.label,
    required this.sublabel,
    required this.averiasCount,
    required this.pendingWorkOrdersCount,
    required this.completedWorkOrdersCount,
    required this.startDate,
    required this.endDate,
  });

  final String label;
  final String sublabel;
  final int averiasCount;
  final int pendingWorkOrdersCount;
  final int completedWorkOrdersCount;
  final DateTime startDate;
  final DateTime endDate;

  int get totalEvents =>
      averiasCount + pendingWorkOrdersCount + completedWorkOrdersCount;

  double get resolutionRate {
    final total = pendingWorkOrdersCount + completedWorkOrdersCount;
    if (total == 0) return 100.0;
    return (completedWorkOrdersCount / total) * 100.0;
  }
}

/// ViewModel para el Tablero General de Control y Monitoreo Ejecutivo.
///
/// Consolida en tiempo real métricas de alto nivel, órdenes de trabajo pendientes,
/// reportes de averías activos, agenda de preventivos y el gráfico interactivo
/// de balance operativo (Averías vs OTs Pendientes vs OTs Completadas).
class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    required this.dashboardRepository,
    required this.getAllWorkOrdersUseCase,
    required this.getAllBreakdownReportsUseCase,
    required this.preventiveScheduleRepository,
  });

  final DashboardRepository dashboardRepository;
  final GetAllWorkOrdersUseCase getAllWorkOrdersUseCase;
  final GetAllBreakdownReportsUseCase getAllBreakdownReportsUseCase;
  final PreventiveScheduleRepository preventiveScheduleRepository;

  DashboardStats? _stats;
  DashboardStats? get stats => _stats;

  List<WorkOrder> _allWorkOrders = [];
  List<WorkOrder> get allWorkOrders => _allWorkOrders;

  List<WorkOrder> _pendingWorkOrders = [];
  List<WorkOrder> get pendingWorkOrders => _pendingWorkOrders;

  List<BreakdownReport> _allBreakdowns = [];
  List<BreakdownReport> get allBreakdowns => _allBreakdowns;

  List<BreakdownReport> _openBreakdowns = [];
  List<BreakdownReport> get openBreakdowns => _openBreakdowns;

  List<PreventiveSchedule> _upcomingSchedules = [];
  List<PreventiveSchedule> get upcomingSchedules => _upcomingSchedules;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  // Estado del gráfico interactivo
  DashboardChartPeriod _chartPeriod = DashboardChartPeriod.mes;
  DashboardChartPeriod get chartPeriod => _chartPeriod;

  // Estado del reporte por Centro de Costo y Tipo de Mantenimiento
  List<CostCenterMaintenanceStats> _costCenterStats = [];
  List<CostCenterMaintenanceStats> get costCenterStats => _costCenterStats;

  bool _isLoadingCostCenters = false;
  bool get isLoadingCostCenters => _isLoadingCostCenters;

  bool _onlyWithMaintenance = true;
  bool get onlyWithMaintenance => _onlyWithMaintenance;

  List<CostCenterMaintenanceDetail> _selectedCostCenterDetails = [];
  List<CostCenterMaintenanceDetail> get selectedCostCenterDetails => _selectedCostCenterDetails;

  bool _isLoadingDetails = false;
  bool get isLoadingDetails => _isLoadingDetails;

  int get totalCostCenterMaintenance =>
      _costCenterStats.fold(0, (sum, c) => sum + c.totalMaintenance);

  int get totalCostCenterCorrective =>
      _costCenterStats.fold(0, (sum, c) => sum + c.corrective);

  int get totalCostCenterPreventive =>
      _costCenterStats.fold(0, (sum, c) => sum + c.preventive);

  int get totalCostCenterPredictive =>
      _costCenterStats.fold(0, (sum, c) => sum + c.predictive);

  int get totalCostCenterImprovement =>
      _costCenterStats.fold(0, (sum, c) => sum + c.improvement);

  int get totalCostCenterOtherTypes =>
      _costCenterStats.fold(0, (sum, c) => sum + c.otherTypes);

  double get totalCostCenterHours =>
      _costCenterStats.fold(0.0, (sum, c) => sum + c.totalRealHours);

  int? _selectedChartPointIndex;
  int? get selectedChartPointIndex => _selectedChartPointIndex;

  bool _showAveriasSeries = true;
  bool get showAveriasSeries => _showAveriasSeries;

  bool _showPendingSeries = true;
  bool get showPendingSeries => _showPendingSeries;

  bool _showCompletedSeries = true;
  bool get showCompletedSeries => _showCompletedSeries;

  void setChartPeriod(DashboardChartPeriod period) {
    if (_chartPeriod == period) return;
    _chartPeriod = period;
    _selectedChartPointIndex = null;
    notifyListeners();
  }

  void selectChartPoint(int? index) {
    if (_selectedChartPointIndex == index) {
      _selectedChartPointIndex = null;
    } else {
      _selectedChartPointIndex = index;
    }
    notifyListeners();
  }

  void toggleAveriasSeries() {
    _showAveriasSeries = !_showAveriasSeries;
    notifyListeners();
  }

  void togglePendingSeries() {
    _showPendingSeries = !_showPendingSeries;
    notifyListeners();
  }

  void toggleCompletedSeries() {
    _showCompletedSeries = !_showCompletedSeries;
    notifyListeners();
  }

  /// Puntos calculados para el gráfico según el periodo activo
  List<DashboardChartPoint> get chartPoints => _computeChartPoints(_chartPeriod);

  int get totalAveriasInPeriod =>
      chartPoints.fold<int>(0, (sum, p) => sum + p.averiasCount);

  int get totalPendingInPeriod =>
      chartPoints.fold<int>(0, (sum, p) => sum + p.pendingWorkOrdersCount);

  int get totalCompletedInPeriod =>
      chartPoints.fold<int>(0, (sum, p) => sum + p.completedWorkOrdersCount);

  double get overallResolutionRate {
    final total = totalPendingInPeriod + totalCompletedInPeriod;
    if (total == 0) return 100.0;
    return (totalCompletedInPeriod / total) * 100.0;
  }

  /// Carga integral de todos los indicadores y listas pendientes del tablero.
  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final results = await Future.wait([
        dashboardRepository.getStats().catchError(
              (_) => const DashboardStats(
                totalAssets: 0,
                pendingWorkOrders: 0,
                inProgressWorkOrders: 0,
                completedWorkOrders: 0,
                activeSchedules: 0,
                totalKardexLogs: 0,
              ),
            ),
        getAllWorkOrdersUseCase(const GetAllWorkOrdersParams()).catchError(
              (_) => <WorkOrder>[],
            ),
        getAllBreakdownReportsUseCase(const GetAllBreakdownReportsParams())
            .catchError(
              (_) => <BreakdownReport>[],
            ),
        preventiveScheduleRepository
            .getAllSchedules(status: ScheduleStatus.active)
            .catchError((_) => <PreventiveSchedule>[]),
      ]);

      _stats = results[0] as DashboardStats;

      // 1. Guardar todas las órdenes de trabajo y priorizar pendientes
      _allWorkOrders = results[1] as List<WorkOrder>;
      _pendingWorkOrders = _allWorkOrders
          .where(
            (wo) =>
                wo.status == WorkOrderStatus.pending ||
                wo.status == WorkOrderStatus.inProgress,
          )
          .toList()
        ..sort((a, b) {
          final priorityCompare = b.priority.index.compareTo(a.priority.index);
          if (priorityCompare != 0) return priorityCompare;
          final dateA = a.scheduledDate ?? a.createdAt ?? DateTime(2000);
          final dateB = b.scheduledDate ?? b.createdAt ?? DateTime(2000);
          return dateA.compareTo(dateB);
        });

      // 2. Guardar todas las averías y priorizar abiertas
      _allBreakdowns = results[2] as List<BreakdownReport>;
      _openBreakdowns = _allBreakdowns.where((b) => b.isOpen).toList()
        ..sort((a, b) {
          final sevCompare = b.severity.index.compareTo(a.severity.index);
          if (sevCompare != 0) return sevCompare;
          final dateA = a.reportedAt ?? DateTime(2000);
          final dateB = b.reportedAt ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

      // 3. Preventivos: vencidos y próximos primero (menor daysRemaining)
      final allSchedules = results[3] as List<PreventiveSchedule>;
      _upcomingSchedules = allSchedules
        ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

      _lastUpdated = DateTime.now();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Cargar estadísticas por Centro de Costo en segundo plano
    await loadCostCenterMaintenance();
  }

  Future<void> toggleOnlyWithMaintenance() async {
    _onlyWithMaintenance = !_onlyWithMaintenance;
    await loadCostCenterMaintenance();
  }

  Future<void> loadCostCenterMaintenance({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoadingCostCenters = true;
    notifyListeners();
    try {
      _costCenterStats = await dashboardRepository.getMaintenanceByCostCenter(
        startDate: startDate,
        endDate: endDate,
        onlyWithMaintenance: _onlyWithMaintenance,
      );
    } catch (e) {
      debugPrint('Error cargando métricas de mantenimiento por centro de costo: $e');
    } finally {
      _isLoadingCostCenters = false;
      notifyListeners();
    }
  }

  Future<List<CostCenterMaintenanceDetail>> getCostCenterDetails({
    String? costCenter,
    String? areaId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoadingDetails = true;
    notifyListeners();
    try {
      _selectedCostCenterDetails =
          await dashboardRepository.getMaintenanceByCostCenterDetails(
        costCenter: costCenter,
        areaId: areaId,
        startDate: startDate,
        endDate: endDate,
      );
      return _selectedCostCenterDetails;
    } catch (e) {
      debugPrint('Error cargando detalle de órdenes por centro de costo: $e');
      return [];
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  /// Método retrocompatible
  Future<void> loadStats() => loadDashboard();

  /// Algoritmo de agregación temporal para el gráfico interactivo
  List<DashboardChartPoint> _computeChartPoints(DashboardChartPeriod period) {
    final now = DateTime.now();

    switch (period) {
      case DashboardChartPeriod.semana:
        // Últimos 7 días hasta hoy
        return List.generate(7, (i) {
          final dayDate = now.subtract(Duration(days: 6 - i));
          final start =
              DateTime(dayDate.year, dayDate.month, dayDate.day, 0, 0, 0);
          final end =
              DateTime(dayDate.year, dayDate.month, dayDate.day, 23, 59, 59);

          const dayNames = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
          final dayName = dayNames[dayDate.weekday % 7];
          final label = '$dayName ${dayDate.day}';
          final sublabel =
              '${dayDate.day.toString().padLeft(2, '0')}/${dayDate.month.toString().padLeft(2, '0')}/${dayDate.year}';

          return _buildPoint(label, sublabel, start, end);
        });

      case DashboardChartPeriod.mes:
        // Mes actual dividido en 4 semanas
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final weekRanges = [
          (1, 7, 'Sem 1'),
          (8, 14, 'Sem 2'),
          (15, 21, 'Sem 3'),
          (22, daysInMonth, 'Sem 4'),
        ];

        const monthNames = [
          '',
          'Ene',
          'Feb',
          'Mar',
          'Abr',
          'May',
          'Jun',
          'Jul',
          'Ago',
          'Sep',
          'Oct',
          'Nov',
          'Dic'
        ];
        final monthName = monthNames[now.month];

        return weekRanges.map((range) {
          final start = DateTime(now.year, now.month, range.$1, 0, 0, 0);
          final end = DateTime(now.year, now.month, range.$2, 23, 59, 59);
          final label = range.$3;
          final sublabel =
              '${range.$1}-${range.$2} $monthName ${now.year}';
          return _buildPoint(label, sublabel, start, end);
        }).toList();

      case DashboardChartPeriod.ano:
        // 12 meses del año actual
        const monthShortNames = [
          '',
          'Ene',
          'Feb',
          'Mar',
          'Abr',
          'May',
          'Jun',
          'Jul',
          'Ago',
          'Sep',
          'Oct',
          'Nov',
          'Dic'
        ];
        return List.generate(12, (i) {
          final m = i + 1;
          final daysInMonth = DateTime(now.year, m + 1, 0).day;
          final start = DateTime(now.year, m, 1, 0, 0, 0);
          final end = DateTime(now.year, m, daysInMonth, 23, 59, 59);
          final label = monthShortNames[m];
          final sublabel = '$label ${now.year}';
          return _buildPoint(label, sublabel, start, end);
        });

      case DashboardChartPeriod.historico:
        // Últimos 4 años (ej. 2023, 2024, 2025, 2026)
        final currentYear = now.year;
        final years = [
          currentYear - 3,
          currentYear - 2,
          currentYear - 1,
          currentYear
        ];
        return years.map((y) {
          final start = DateTime(y, 1, 1, 0, 0, 0);
          final end = DateTime(y, 12, 31, 23, 59, 59);
          final label = '$y';
          final sublabel = 'Año $y';
          return _buildPoint(label, sublabel, start, end);
        }).toList();
    }
  }

  DashboardChartPoint _buildPoint(
    String label,
    String sublabel,
    DateTime start,
    DateTime end,
  ) {
    final startSec = start.subtract(const Duration(seconds: 1));
    final endSec = end.add(const Duration(seconds: 1));

    // 1. Averías reportadas en el periodo
    final averiasInPeriod = _allBreakdowns.where((b) {
      if (b.reportedAt == null) return false;
      return b.reportedAt!.isAfter(startSec) && b.reportedAt!.isBefore(endSec);
    }).length;

    // 2. OTs pendientes en el periodo
    final pendingInPeriod = _allWorkOrders.where((wo) {
      final isOpen = wo.status == WorkOrderStatus.pending ||
          wo.status == WorkOrderStatus.inProgress;
      if (!isOpen) return false;
      final refDate = wo.scheduledDate ?? wo.createdAt;
      if (refDate == null) return false;
      return refDate.isAfter(startSec) && refDate.isBefore(endSec);
    }).length;

    // 3. OTs completadas en el periodo
    final completedInPeriod = _allWorkOrders.where((wo) {
      if (wo.status != WorkOrderStatus.completed) return false;
      final refDate = wo.createdAt ?? wo.scheduledDate;
      if (refDate == null) return false;
      return refDate.isAfter(startSec) && refDate.isBefore(endSec);
    }).length;

    return DashboardChartPoint(
      label: label,
      sublabel: sublabel,
      averiasCount: averiasInPeriod,
      pendingWorkOrdersCount: pendingInPeriod,
      completedWorkOrdersCount: completedInPeriod,
      startDate: start,
      endDate: end,
    );
  }
}
