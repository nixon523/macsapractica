import '../entities/operation_report.dart';
import '../repositories/operation_report_repository.dart';

class ObtenerReportesPorActivo {
  const ObtenerReportesPorActivo(this.repository);
  final OperationReportRepository repository;

  Future<List<OperationReport>> call(
    String codigoActivo, {
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int pagina = 1,
    int registrosPorPagina = 30,
  }) {
    return repository.obtenerPorActivo(
      codigoActivo,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
      pagina: pagina,
      registrosPorPagina: registrosPorPagina,
    );
  }
}
