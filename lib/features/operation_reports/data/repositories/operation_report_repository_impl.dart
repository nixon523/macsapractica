import '../../domain/entities/operation_report.dart';
import '../../domain/repositories/operation_report_repository.dart';
import '../datasources/operation_report_remote_datasource.dart';

class OperationReportRepositoryImpl implements OperationReportRepository {
  const OperationReportRepositoryImpl(this._remoteDataSource);
  final OperationReportRemoteDataSource _remoteDataSource;

  @override
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
  }) {
    return _remoteDataSource.registrarReporte(
      codigoActivo: codigoActivo,
      fechaOperacion: fechaOperacion,
      horasTotalesJornada: horasTotalesJornada,
      horasOperacion: horasOperacion,
      horasParoFalla: horasParoFalla,
      horasParoMantPrev: horasParoMantPrev,
      horasParoMantCorr: horasParoMantCorr,
      horasParoPlanificado: horasParoPlanificado,
      horasParoExterno: horasParoExterno,
      observaciones: observaciones,
    );
  }

  @override
  Future<List<OperationReport>> obtenerPorActivo(
    String codigoActivo, {
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int pagina = 1,
    int registrosPorPagina = 30,
  }) {
    return _remoteDataSource.obtenerPorActivo(
      codigoActivo,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
      pagina: pagina,
      registrosPorPagina: registrosPorPagina,
    );
  }

  @override
  Future<List<OperationReport>> obtenerPorSemana(
    String areaId,
    DateTime lunesDeLaSemana,
  ) {
    return _remoteDataSource.obtenerPorSemana(areaId, lunesDeLaSemana);
  }

  @override
  Future<OperationMetrics> obtenerMetricas(
    String codigoActivo,
    DateTime fechaDesde,
    DateTime fechaHasta,
  ) {
    return _remoteDataSource.obtenerMetricas(
      codigoActivo,
      fechaDesde,
      fechaHasta,
    );
  }

  @override
  Future<List<EquipoProceso>> listarEquiposProceso(String? areaId) {
    return _remoteDataSource.listarEquiposProceso(areaId);
  }

  @override
  Future<void> actualizarEsEquipoProceso(
    String codigoActivo, {
    required bool esEquipoProceso,
  }) {
    return _remoteDataSource.actualizarEsEquipoProceso(
      codigoActivo,
      esEquipoProceso: esEquipoProceso,
    );
  }
}
