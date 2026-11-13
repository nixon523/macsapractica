import 'package:flutter/material.dart';

import '../../domain/entities/maintenance_analytics.dart';
import '../../domain/usecases/obtener_analitica_mantenimiento.dart';

class MaintenanceAnalyticsViewModel extends ChangeNotifier {
  MaintenanceAnalyticsViewModel({
    required this.analyticsUseCase,
  });

  final ObtenerAnaliticaMantenimientoUseCase analyticsUseCase;

  // Estados de carga
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Datos de Hoja de Vida / Historial por Equipo
  AssetHistoryAnalytics? _assetHistory;
  AssetHistoryAnalytics? get assetHistory => _assetHistory;

  // Datos de Estacionalidad Anual
  List<SeasonalityStat> _seasonalityStats = [];
  List<SeasonalityStat> get seasonalityStats => _seasonalityStats;

  // Datos de Top Fallas (Pareto)
  List<TopFailureAsset> _topFailures = [];
  List<TopFailureAsset> get topFailures => _topFailures;

  // Datos de Repuestos
  List<PartReplacementStat> _partsConsumption = [];
  List<PartReplacementStat> get partsConsumption => _partsConsumption;

  // Datos de OEE General
  List<OeeGeneralRecord> _oeeRecords = [];
  List<OeeGeneralRecord> get oeeRecords => _oeeRecords;

  // Cargar Hoja de Vida de un Activo
  Future<void> loadAssetHistory(
    String codigoActivo, {
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    bool incluirHijos = true,
  }) async {
    _setLoading(true);
    try {
      _assetHistory = await analyticsUseCase.obtenerHistorialActivo(
        codigoActivo,
        fechaDesde: fechaDesde,
        fechaHasta: fechaHasta,
        incluirHijos: incluirHijos,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error al cargar historial del equipo: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Cargar Dashboard de Tendencias y Estacionalidad
  Future<void> loadDashboardAnalytics({
    String? areaId,
    int? anio,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    _setLoading(true);
    try {
      final results = await Future.wait([
        analyticsUseCase.obtenerEstacionalidad(areaId: areaId, anio: anio),
        analyticsUseCase.obtenerTopFallas(areaId: areaId, fechaDesde: fechaDesde, fechaHasta: fechaHasta, top: 10),
        analyticsUseCase.obtenerConsumoRepuestos(areaId: areaId, fechaDesde: fechaDesde, fechaHasta: fechaHasta, top: 20),
        analyticsUseCase.obtenerOEEGeneral(areaId: areaId, fechaDesde: fechaDesde, fechaHasta: fechaHasta),
      ]);

      _seasonalityStats = results[0] as List<SeasonalityStat>;
      _topFailures = results[1] as List<TopFailureAsset>;
      _partsConsumption = results[2] as List<PartReplacementStat>;
      _oeeRecords = results[3] as List<OeeGeneralRecord>;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error al cargar analítica de mantenimiento: $e';
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
