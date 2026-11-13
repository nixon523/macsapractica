import '../entities/maintenance_analytics.dart';
import '../entities/operation_report.dart';

abstract class OperationReportRepository {
  Future<OperationReport> registrarReporte({
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
  });

  Future<List<OperationReport>> obtenerPorActivo(
    String codigoActivo, {
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int pagina = 1,
    int registrosPorPagina = 30,
  });

  Future<List<OperationReport>> obtenerPorSemana(
    String areaId,
    DateTime lunesDeLaSemana,
  );

  Future<OperationMetrics> obtenerMetricas(
    String codigoActivo,
    DateTime fechaDesde,
    DateTime fechaHasta,
  );

  Future<List<EquipoProceso>> listarEquiposProceso(String? areaId);

  Future<void> actualizarEsEquipoProceso(
    String codigoActivo, {
    required bool esEquipoProceso,
  });

  // Analítica & Reportería
  Future<AssetHistoryAnalytics> obtenerHistorialActivo(
    String codigoActivo, {
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    bool incluirHijos = true,
  });

  Future<List<SeasonalityStat>> obtenerEstacionalidad({
    String? areaId,
    int? anio,
  });

  Future<List<TopFailureAsset>> obtenerTopFallas({
    String? areaId,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int top = 10,
  });

  Future<List<PartReplacementStat>> obtenerConsumoRepuestos({
    String? areaId,
    String? codigoActivo,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int top = 20,
  });

  Future<List<OeeGeneralRecord>> obtenerOEEGeneral({
    String? areaId,
    String? codigoActivo,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  });
}
