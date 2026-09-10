import '../entities/operation_report.dart';
import '../repositories/operation_report_repository.dart';

class RegistrarReporteOperacion {
  const RegistrarReporteOperacion(this.repository);
  final OperationReportRepository repository;

  Future<OperationReport> call({
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
    return repository.registrarReporte(
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
}
