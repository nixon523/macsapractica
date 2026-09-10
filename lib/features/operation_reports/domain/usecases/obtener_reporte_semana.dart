import '../entities/operation_report.dart';
import '../repositories/operation_report_repository.dart';

class ObtenerReporteSemana {
  const ObtenerReporteSemana(this.repository);
  final OperationReportRepository repository;

  Future<List<OperationReport>> call(String areaId, DateTime lunesDeLaSemana) {
    return repository.obtenerPorSemana(areaId, lunesDeLaSemana);
  }
}
