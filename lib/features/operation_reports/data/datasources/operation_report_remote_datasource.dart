import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/operation_report_model.dart';

/// DataSource remoto para reportes de operación diaria.
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
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.operationReports,
      body: {
        'codigoActivo':         codigoActivo,
        'fechaOperacion':       '${fechaOperacion.year.toString().padLeft(4,"0")}-'
                                '${fechaOperacion.month.toString().padLeft(2,"0")}-'
                                '${fechaOperacion.day.toString().padLeft(2,"0")}',
        'horasTotalesJornada':  horasTotalesJornada,
        'horasOperacion':       horasOperacion,
        'horasParoFalla':       horasParoFalla,
        'horasParoMantPrev':    horasParoMantPrev,
        'horasParoMantCorr':    horasParoMantCorr,
        'horasParoPlanificado': horasParoPlanificado,
        'horasParoExterno':     horasParoExterno,
        if (observaciones != null) 'observaciones': observaciones,
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

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4,"0")}-'
      '${d.month.toString().padLeft(2,"0")}-'
      '${d.day.toString().padLeft(2,"0")}';
}
