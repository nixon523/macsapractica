import '../entities/operation_report.dart';
import '../repositories/operation_report_repository.dart';

class ObtenerMetricasOperacion {
  const ObtenerMetricasOperacion(this.repository);
  final OperationReportRepository repository;

  Future<OperationMetrics> call(
    String codigoActivo,
    DateTime fechaDesde,
    DateTime fechaHasta,
  ) {
    return repository.obtenerMetricas(codigoActivo, fechaDesde, fechaHasta);
  }
}
