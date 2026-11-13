import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/maintenance_analytics.dart';
import '../models/operation_report_model.dart';

/// DataSource remoto para reportes de operación diaria y analítica avanzada.
class OperationReportRemoteDataSource {
  const OperationReportRemoteDataSource(this._apiClient);
  final ApiClient _apiClient;

  Future<OperationReportModel> registrarReporte({
    required String codigoActivo,
    required DateTime fechaOperacion,
    double horasTotalesJornada = 24.0,
    required double horasOperacion,
    double horasParoFalla = 0.0,
    double horasParoMantPrev = 0.0,
    double horasParoMantCorr = 0.0,
    double horasParoPlanificado = 0.0,
    double horasParoExterno = 0.0,
    String? observaciones,
    double? unidadesProducidas,
    double? unidadesEsperadas,
    double? unidadesConformes,
    double? rendimientoDirectoPct,
    double? calidadDirectoPct,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.operationReports,
      body: {
        'codigoActivo':          codigoActivo,
        'fechaOperacion':        _formatDate(fechaOperacion),
        'horasTotalesJornada':   horasTotalesJornada,
        'horasOperacion':        horasOperacion,
        'horasParoFalla':        horasParoFalla,
        'horasParoMantPrev':     horasParoMantPrev,
        'horasParoMantCorr':     horasParoMantCorr,
        'horasParoPlanificado':  horasParoPlanificado,
        'horasParoExterno':      horasParoExterno,
        if (observaciones != null) 'observaciones': observaciones,
        if (unidadesProducidas != null) 'unidadesProducidas': unidadesProducidas,
        if (unidadesEsperadas != null) 'unidadesEsperadas': unidadesEsperadas,
        if (unidadesConformes != null) 'unidadesConformes': unidadesConformes,
        if (rendimientoDirectoPct != null) 'rendimientoDirectoPct': rendimientoDirectoPct,
        if (calidadDirectoPct != null) 'calidadDirectoPct': calidadDirectoPct,
      },
    );
    if (response is Map<String, dynamic>) {
      return OperationReportModel.fromJson(response);
    }
    throw Exception('Respuesta inesperada del servidor al registrar reporte.');
  }

  Future<List<OperationReportModel>> obtenerPorActivo(
    String codigoActivo, {
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int pagina = 1,
    int registrosPorPagina = 30,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.operationReportsByAsset(codigoActivo),
      queryParameters: {
        if (fechaDesde != null) 'fechaDesde': _formatDate(fechaDesde),
        if (fechaHasta != null) 'fechaHasta': _formatDate(fechaHasta),
        'pagina':             pagina,
        'registrosPorPagina': registrosPorPagina,
      },
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(OperationReportModel.fromJson)
          .toList();
    }
    return [];
  }

  Future<List<OperationReportModel>> obtenerPorSemana(
    String areaId,
    DateTime lunesDeLaSemana,
  ) async {
    final response = await _apiClient.get(
      ApiEndpoints.operationReportsWeek,
      queryParameters: {
        'areaId': areaId,
        'lunes':  _formatDate(lunesDeLaSemana),
      },
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(OperationReportModel.fromJson)
          .toList();
    }
    return [];
  }

  Future<OperationMetricsModel> obtenerMetricas(
    String codigoActivo,
    DateTime fechaDesde,
    DateTime fechaHasta,
  ) async {
    final response = await _apiClient.get(
      ApiEndpoints.operationReportMetrics(codigoActivo),
      queryParameters: {
        'desde': _formatDate(fechaDesde),
        'hasta': _formatDate(fechaHasta),
      },
    );
    if (response is Map<String, dynamic>) {
      return OperationMetricsModel.fromJson(response);
    }
    throw Exception('Respuesta inesperada del servidor al obtener métricas.');
  }

  Future<List<EquipoProcesoModel>> listarEquiposProceso(String? areaId) async {
    final response = await _apiClient.get(
      ApiEndpoints.processEquipment,
      queryParameters: {if (areaId != null) 'areaId': areaId},
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(EquipoProcesoModel.fromJson)
          .toList();
    }
    return [];
  }

  Future<void> actualizarEsEquipoProceso(
    String codigoActivo, {
    required bool esEquipoProceso,
  }) async {
    await _apiClient.patch(
      ApiEndpoints.toggleProcessEquipment(codigoActivo),
      body: {'esEquipoProceso': esEquipoProceso},
    );
  }

  // --- MÉTODOS DE ANALÍTICA AVANZADA Y HOJA DE VIDA ---

  Future<AssetHistoryAnalytics> obtenerHistorialActivo(
    String codigoActivo, {
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    bool incluirHijos = true,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.analyticsAssetHistory(codigoActivo),
      queryParameters: {
        if (fechaDesde != null) 'fechaDesde': _formatDate(fechaDesde),
        if (fechaHasta != null) 'fechaHasta': _formatDate(fechaHasta),
        'incluirHijos': incluirHijos.toString(),
      },
    );

    if (response is Map<String, dynamic>) {
      final resumenJson = response['resumen'] is Map<String, dynamic>
          ? response['resumen'] as Map<String, dynamic>
          : <String, dynamic>{};
      final timelineList = response['timeline'] is List
          ? (response['timeline'] as List)
              .whereType<Map<String, dynamic>>()
              .map(MaintenanceIntervention.fromJson)
              .toList()
          : <MaintenanceIntervention>[];
      final repuestosList = response['repuestos'] is List
          ? (response['repuestos'] as List)
              .whereType<Map<String, dynamic>>()
              .map(PartReplacementStat.fromJson)
              .toList()
          : <PartReplacementStat>[];

      return AssetHistoryAnalytics(
        resumen: AssetKpiSummary.fromJson(resumenJson),
        timeline: timelineList,
        repuestos: repuestosList,
      );
    }

    throw Exception('Error al obtener la hoja de vida del activo.');
  }

  Future<List<SeasonalityStat>> obtenerEstacionalidad({
    String? areaId,
    int? anio,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.analyticsSeasonality,
      queryParameters: {
        if (areaId != null && areaId.isNotEmpty) 'areaId': areaId,
        if (anio != null) 'anio': anio,
      },
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(SeasonalityStat.fromJson)
          .toList();
    }
    return [];
  }

  Future<List<TopFailureAsset>> obtenerTopFallas({
    String? areaId,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int top = 10,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.analyticsTopFailures,
      queryParameters: {
        if (areaId != null && areaId.isNotEmpty) 'areaId': areaId,
        if (fechaDesde != null) 'fechaDesde': _formatDate(fechaDesde),
        if (fechaHasta != null) 'fechaHasta': _formatDate(fechaHasta),
        'top': top,
      },
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(TopFailureAsset.fromJson)
          .toList();
    }
    return [];
  }

  Future<List<PartReplacementStat>> obtenerConsumoRepuestos({
    String? areaId,
    String? codigoActivo,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int top = 20,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.analyticsPartsConsumption,
      queryParameters: {
        if (areaId != null && areaId.isNotEmpty) 'areaId': areaId,
        if (codigoActivo != null && codigoActivo.isNotEmpty) 'codigoActivo': codigoActivo,
        if (fechaDesde != null) 'fechaDesde': _formatDate(fechaDesde),
        if (fechaHasta != null) 'fechaHasta': _formatDate(fechaHasta),
        'top': top,
      },
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(PartReplacementStat.fromJson)
          .toList();
    }
    return [];
  }

  Future<List<OeeGeneralRecord>> obtenerOEEGeneral({
    String? areaId,
    String? codigoActivo,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.analyticsOeeGeneral,
      queryParameters: {
        if (areaId != null && areaId.isNotEmpty) 'areaId': areaId,
        if (codigoActivo != null && codigoActivo.isNotEmpty) 'codigoActivo': codigoActivo,
        if (fechaDesde != null) 'fechaDesde': _formatDate(fechaDesde),
        if (fechaHasta != null) 'fechaHasta': _formatDate(fechaHasta),
      },
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(OeeGeneralRecord.fromJson)
          .toList();
    }
    return [];
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, "0")}-'
      '${d.month.toString().padLeft(2, "0")}-'
      '${d.day.toString().padLeft(2, "0")}';
}
