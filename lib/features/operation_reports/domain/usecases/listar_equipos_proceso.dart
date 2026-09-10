import '../entities/operation_report.dart';
import '../repositories/operation_report_repository.dart';

class ListarEquiposProceso {
  const ListarEquiposProceso(this.repository);
  final OperationReportRepository repository;

  Future<List<EquipoProceso>> call(String? areaId) =>
      repository.listarEquiposProceso(areaId);
}
