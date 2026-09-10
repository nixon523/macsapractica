import '../repositories/operation_report_repository.dart';

class ActualizarEsEquipoProceso {
  const ActualizarEsEquipoProceso(this.repository);
  final OperationReportRepository repository;

  Future<void> call(String codigoActivo, {required bool esEquipoProceso}) =>
      repository.actualizarEsEquipoProceso(
        codigoActivo,
        esEquipoProceso: esEquipoProceso,
      );
}
