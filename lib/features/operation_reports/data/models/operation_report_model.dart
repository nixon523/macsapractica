import '../../domain/entities/operation_report.dart';

class OperationReportModel extends OperationReport {
  const OperationReportModel({
    super.reporteId,
    required super.codigoActivo,
    required super.nombreActivo,
    required super.areaId,
    super.nombreArea,
    required super.fechaOperacion,
    required super.horasTotalesJornada,
    required super.horasOperacion,
    required super.horasParoFalla,
    required super.horasParoMantPrev,
    required super.horasParoMantCorr,
    required super.horasParoPlanificado,
    required super.horasParoExterno,
    super.observaciones,
    super.semanaISO,
    super.registradoPorUsuarioId,
    super.registradoPorNombreUsuario,
    super.registradoEn,
    super.disponibilidadPct,
  });

  factory OperationReportModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    DateTime? parseDateOpt(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return OperationReportModel(
      reporteId:                   _parseInt(json['ReporteId'] ?? json['reporteId']),
      codigoActivo:                (json['CodigoActivo']   ?? json['codigoActivo']   ?? '').toString(),
      nombreActivo:                (json['NombreActivo']   ?? json['nombreActivo']   ?? '').toString(),
      areaId:                      (json['AreaId']         ?? json['areaId']         ?? '').toString(),
      nombreArea:                  (json['NombreArea']     ?? json['nombreArea'])?.toString(),
      fechaOperacion:              parseDate(json['FechaOperacion'] ?? json['fechaOperacion']),
      horasTotalesJornada:         _toDouble(json['HorasTotalesJornada'] ?? json['horasTotalesJornada']) ?? 24.0,
      horasOperacion:              _toDouble(json['HorasOperacion']      ?? json['horasOperacion'])      ?? 0.0,
      horasParoFalla:              _toDouble(json['HorasParoFalla']      ?? json['horasParoFalla'])      ?? 0.0,
      horasParoMantPrev:           _toDouble(json['HorasParoMantPrev']   ?? json['horasParoMantPrev'])   ?? 0.0,
      horasParoMantCorr:           _toDouble(json['HorasParoMantCorr']   ?? json['horasParoMantCorr'])   ?? 0.0,
      horasParoPlanificado:        _toDouble(json['HorasParoPlanificado']?? json['horasParoPlanificado'])?? 0.0,
      horasParoExterno:            _toDouble(json['HorasParoExterno']    ?? json['horasParoExterno'])    ?? 0.0,
      observaciones:               (json['Observaciones']  ?? json['observaciones'])?.toString(),
      semanaISO:                   (json['SemanaISO']      ?? json['semanaISO'])?.toString(),
      registradoPorUsuarioId:      _parseInt(json['RegistradoPorUsuarioId'] ?? json['registradoPorUsuarioId']),
      registradoPorNombreUsuario:  (json['RegistradoPorNombreUsuario'] ?? json['registradoPorNombreUsuario'])?.toString(),
      registradoEn:                parseDateOpt(json['RegistradoEn'] ?? json['registradoEn']),
      disponibilidadPct:           _toDouble(json['DisponibilidadPct'] ?? json['disponibilidadPct']),
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class OperationMetricsModel extends OperationMetrics {
  const OperationMetricsModel({
    required super.codigoActivo,
    required super.fechaDesde,
    required super.fechaHasta,
    required super.diasConReporte,
    required super.totalHorasJornada,
    required super.totalHorasOperacion,
    required super.totalParoFalla,
    required super.totalParoMantPrev,
    required super.totalParoMantCorr,
    required super.totalParoPlanificado,
    required super.totalParoExterno,
    required super.disponibilidadPct,
    super.mtbfHoras,
    super.mttrHoras,
  });

  factory OperationMetricsModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    double toD(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    double? toDOpt(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return OperationMetricsModel(
      codigoActivo:          (json['CodigoActivo']          ?? json['codigoActivo'] ?? '').toString(),
      fechaDesde:             parseDate(json['FechaDesde']   ?? json['fechaDesde']),
      fechaHasta:             parseDate(json['FechaHasta']   ?? json['fechaHasta']),
      diasConReporte:         (json['DiasConReporte']        ?? json['diasConReporte'] ?? 0) as int,
      totalHorasJornada:      toD(json['TotalHorasJornada']  ?? json['totalHorasJornada']),
      totalHorasOperacion:    toD(json['TotalHorasOperacion']?? json['totalHorasOperacion']),
      totalParoFalla:         toD(json['TotalParoFalla']     ?? json['totalParoFalla']),
      totalParoMantPrev:      toD(json['TotalParoMantPrev']  ?? json['totalParoMantPrev']),
      totalParoMantCorr:      toD(json['TotalParoMantCorr']  ?? json['totalParoMantCorr']),
      totalParoPlanificado:   toD(json['TotalParoPlanificado']??json['totalParoPlanificado']),
      totalParoExterno:       toD(json['TotalParoExterno']   ?? json['totalParoExterno']),
      disponibilidadPct:      toD(json['DisponibilidadPct']  ?? json['disponibilidadPct']),
      mtbfHoras:              toDOpt(json['MTBF_Horas']      ?? json['mtbfHoras']),
      mttrHoras:              toDOpt(json['MTTR_Horas']      ?? json['mttrHoras']),
    );
  }
}

class EquipoProcesoModel extends EquipoProceso {
  const EquipoProcesoModel({
    required super.codigoActivo,
    required super.nombre,
    super.marca,
    super.modelo,
    required super.areaId,
    super.nombreArea,
  });

  factory EquipoProcesoModel.fromJson(Map<String, dynamic> json) {
    return EquipoProcesoModel(
      codigoActivo: (json['CodigoActivo'] ?? json['codigoActivo'] ?? '').toString(),
      nombre:       (json['Nombre']       ?? json['nombre']       ?? '').toString(),
      marca:        (json['Marca']        ?? json['marca'])?.toString(),
      modelo:       (json['Modelo']       ?? json['modelo'])?.toString(),
      areaId:       (json['AreaId']       ?? json['areaId']       ?? '').toString(),
      nombreArea:   (json['NombreArea']   ?? json['nombreArea'])?.toString(),
    );
  }
}
