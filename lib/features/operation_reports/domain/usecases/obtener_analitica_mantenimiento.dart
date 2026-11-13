import '../entities/maintenance_analytics.dart';
import '../repositories/operation_report_repository.dart';

class ObtenerAnaliticaMantenimientoUseCase {
  const ObtenerAnaliticaMantenimientoUseCase(this._repository);
  final OperationReportRepository _repository;

  Future<AssetHistoryAnalytics> obtenerHistorialActivo(
    String codigoActivo, {
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    bool incluirHijos = true,
  }) {
    return _repository.obtenerHistorialActivo(
      codigoActivo,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
      incluirHijos: incluirHijos,
    );
  }

  Future<List<SeasonalityStat>> obtenerEstacionalidad({
    String? areaId,
    int? anio,
  }) {
    return _repository.obtenerEstacionalidad(
      areaId: areaId,
      anio: anio,
    );
  }

  Future<List<TopFailureAsset>> obtenerTopFallas({
    String? areaId,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int top = 10,
  }) {
    return _repository.obtenerTopFallas(
      areaId: areaId,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
      top: top,
    );
  }

  Future<List<PartReplacementStat>> obtenerConsumoRepuestos({
    String? areaId,
    String? codigoActivo,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int top = 20,
  }) {
    return _repository.obtenerConsumoRepuestos(
      areaId: areaId,
      codigoActivo: codigoActivo,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
      top: top,
    );
  }

  Future<List<OeeGeneralRecord>> obtenerOEEGeneral({
    String? areaId,
    String? codigoActivo,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) {
    return _repository.obtenerOEEGeneral(
      areaId: areaId,
      codigoActivo: codigoActivo,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
    );
  }
}

