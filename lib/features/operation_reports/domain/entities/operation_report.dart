/// Representa el reporte de operación de un día para un equipo de proceso.
class OperationReport {
  const OperationReport({
    this.reporteId,
    required this.codigoActivo,
    required this.nombreActivo,
    required this.areaId,
    this.nombreArea,
    required this.fechaOperacion,
    required this.horasTotalesJornada,
    required this.horasOperacion,
    required this.horasParoFalla,
    required this.horasParoMantPrev,
    required this.horasParoMantCorr,
    required this.horasParoPlanificado,
    required this.horasParoExterno,
    this.observaciones,
    this.semanaISO,
    this.registradoPorUsuarioId,
    this.registradoPorNombreUsuario,
    this.registradoEn,
    this.disponibilidadPct,
  });

  final int? reporteId;
  final String codigoActivo;
  final String nombreActivo;
  final String areaId;
  final String? nombreArea;
  final DateTime fechaOperacion;
  final double horasTotalesJornada;
  final double horasOperacion;
  final double horasParoFalla;
  final double horasParoMantPrev;
  final double horasParoMantCorr;
  final double horasParoPlanificado;
  final double horasParoExterno;
  final String? observaciones;
  final String? semanaISO;
  final int? registradoPorUsuarioId;
  final String? registradoPorNombreUsuario;
  final DateTime? registradoEn;
  final double? disponibilidadPct;

  double get disponibilidad {
    if (disponibilidadPct != null) return disponibilidadPct!;
    if (horasTotalesJornada <= 0) return 0;
    return ((horasOperacion / horasTotalesJornada) * 100).clamp(0.0, 100.0);
  }

  double get totalParos =>
      horasParoFalla + horasParoMantPrev + horasParoMantCorr +
      horasParoPlanificado + horasParoExterno;

  double get horasNoContabilizadas =>
      (horasTotalesJornada - horasOperacion - totalParos).clamp(0.0, 24.0);

  bool get tieneReporte => reporteId != null;

  OperationReport copyWith({
    int? reporteId,
    double? horasTotalesJornada,
    double? horasOperacion,
    double? horasParoFalla,
    double? horasParoMantPrev,
    double? horasParoMantCorr,
    double? horasParoPlanificado,
    double? horasParoExterno,
    String? observaciones,
  }) {
    return OperationReport(
      reporteId: reporteId ?? this.reporteId,
      codigoActivo: codigoActivo,
      nombreActivo: nombreActivo,
      areaId: areaId,
      nombreArea: nombreArea,
      fechaOperacion: fechaOperacion,
      horasTotalesJornada: horasTotalesJornada ?? this.horasTotalesJornada,
      horasOperacion: horasOperacion ?? this.horasOperacion,
      horasParoFalla: horasParoFalla ?? this.horasParoFalla,
      horasParoMantPrev: horasParoMantPrev ?? this.horasParoMantPrev,
      horasParoMantCorr: horasParoMantCorr ?? this.horasParoMantCorr,
      horasParoPlanificado: horasParoPlanificado ?? this.horasParoPlanificado,
      horasParoExterno: horasParoExterno ?? this.horasParoExterno,
      observaciones: observaciones ?? this.observaciones,
      semanaISO: semanaISO,
      registradoPorUsuarioId: registradoPorUsuarioId,
      registradoPorNombreUsuario: registradoPorNombreUsuario,
      registradoEn: registradoEn,
      disponibilidadPct: disponibilidadPct,
    );
  }
}

class OperationMetrics {
  const OperationMetrics({
    required this.codigoActivo,
    required this.fechaDesde,
    required this.fechaHasta,
    required this.diasConReporte,
    required this.totalHorasJornada,
    required this.totalHorasOperacion,
    required this.totalParoFalla,
    required this.totalParoMantPrev,
    required this.totalParoMantCorr,
    required this.totalParoPlanificado,
    required this.totalParoExterno,
    required this.disponibilidadPct,
    this.mtbfHoras,
    this.mttrHoras,
  });

  final String codigoActivo;
  final DateTime fechaDesde;
  final DateTime fechaHasta;
  final int diasConReporte;
  final double totalHorasJornada;
  final double totalHorasOperacion;
  final double totalParoFalla;
  final double totalParoMantPrev;
  final double totalParoMantCorr;
  final double totalParoPlanificado;
  final double totalParoExterno;
  final double disponibilidadPct;
  final double? mtbfHoras;
  final double? mttrHoras;

  double get totalParos =>
      totalParoFalla + totalParoMantPrev + totalParoMantCorr +
      totalParoPlanificado + totalParoExterno;
}

class EquipoProceso {
  const EquipoProceso({
    required this.codigoActivo,
    required this.nombre,
    this.marca,
    this.modelo,
    required this.areaId,
    this.nombreArea,
  });

  final String codigoActivo;
  final String nombre;
  final String? marca;
  final String? modelo;
  final String areaId;
  final String? nombreArea;
}
