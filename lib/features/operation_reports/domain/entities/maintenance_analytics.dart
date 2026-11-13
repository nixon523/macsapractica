library;

/// Entidades para Reportería y Analítica Avanzada de Mantenimiento / OEE.

class AssetHistoryAnalytics {
  const AssetHistoryAnalytics({
    required this.resumen,
    required this.timeline,
    required this.repuestos,
  });

  final AssetKpiSummary resumen;
  final List<MaintenanceIntervention> timeline;
  final List<PartReplacementStat> repuestos;
}

class AssetKpiSummary {
  const AssetKpiSummary({
    required this.codigoActivo,
    required this.nombreActivo,
    this.marca,
    this.modelo,
    this.serie,
    required this.nivel,
    required this.areaId,
    required this.nombreArea,
    required this.estadoActivo,
    required this.esEquipoProceso,
    required this.totalAverias,
    required this.totalAveriasCriticas,
    required this.totalAveriasResueltas,
    required this.totalOrdenesTrabajo,
    required this.totalOTsPreventivas,
    required this.totalOTsCorrectivas,
    required this.totalOTsCompletadas,
    required this.horasTotalesTaller,
    this.mttrHorasPromedio,
    this.mtbfDiasEstimado,
    this.disponibilidadPromedioPct,
    this.oeePromedioPct,
  });

  final String codigoActivo;
  final String nombreActivo;
  final String? marca;
  final String? modelo;
  final String? serie;
  final String nivel;
  final String areaId;
  final String nombreArea;
  final String estadoActivo;
  final bool esEquipoProceso;
  final int totalAverias;
  final int totalAveriasCriticas;
  final int totalAveriasResueltas;
  final int totalOrdenesTrabajo;
  final int totalOTsPreventivas;
  final int totalOTsCorrectivas;
  final int totalOTsCompletadas;
  final double horasTotalesTaller;
  final double? mttrHorasPromedio;
  final double? mtbfDiasEstimado;
  final double? disponibilidadPromedioPct;
  final double? oeePromedioPct;

  factory AssetKpiSummary.fromJson(Map<String, dynamic> json) {
    return AssetKpiSummary(
      codigoActivo: json['CodigoActivo']?.toString() ?? '',
      nombreActivo: json['NombreActivo']?.toString() ?? '',
      marca: json['Marca']?.toString(),
      modelo: json['Modelo']?.toString(),
      serie: json['Serie']?.toString(),
      nivel: json['Nivel']?.toString() ?? '',
      areaId: json['AreaId']?.toString() ?? '',
      nombreArea: json['NombreArea']?.toString() ?? '',
      estadoActivo: json['EstadoActivo']?.toString() ?? '',
      esEquipoProceso: json['EsEquipoProceso'] == true || json['EsEquipoProceso'] == 1,
      totalAverias: (json['TotalAverias'] as num?)?.toInt() ?? 0,
      totalAveriasCriticas: (json['TotalAveriasCriticas'] as num?)?.toInt() ?? 0,
      totalAveriasResueltas: (json['TotalAveriasResueltas'] as num?)?.toInt() ?? 0,
      totalOrdenesTrabajo: (json['TotalOrdenesTrabajo'] as num?)?.toInt() ?? 0,
      totalOTsPreventivas: (json['TotalOTsPreventivas'] as num?)?.toInt() ?? 0,
      totalOTsCorrectivas: (json['TotalOTsCorrectivas'] as num?)?.toInt() ?? 0,
      totalOTsCompletadas: (json['TotalOTsCompletadas'] as num?)?.toInt() ?? 0,
      horasTotalesTaller: (json['HorasTotalesTaller'] as num?)?.toDouble() ?? 0.0,
      mttrHorasPromedio: (json['MTTR_HorasPromedio'] as num?)?.toDouble(),
      mtbfDiasEstimado: (json['MTBF_DiasEstimado'] as num?)?.toDouble(),
      disponibilidadPromedioPct: (json['DisponibilidadPromedioPct'] as num?)?.toDouble(),
      oeePromedioPct: (json['OeePromedioPct'] as num?)?.toDouble(),
    );
  }
}

class MaintenanceIntervention {
  const MaintenanceIntervention({
    required this.tipoIntervencion,
    required this.id,
    required this.codigoActivo,
    required this.nombreActivo,
    required this.nivelActivo,
    required this.fecha,
    required this.titulo,
    required this.descripcion,
    required this.estado,
    this.severidadOPrioridad,
    this.horasReales,
    this.asignadoA,
    this.responsable,
    this.ordenTrabajoVinculadaId,
  });

  final String tipoIntervencion; // 'AVERIA' | 'OT_PREVENTIVA' | 'OT_CORRECTIVA' | 'OT_GENERAL'
  final String id;
  final String codigoActivo;
  final String nombreActivo;
  final String nivelActivo;
  final DateTime fecha;
  final String titulo;
  final String descripcion;
  final String estado;
  final String? severidadOPrioridad;
  final double? horasReales;
  final String? asignadoA;
  final String? responsable;
  final String? ordenTrabajoVinculadaId;

  factory MaintenanceIntervention.fromJson(Map<String, dynamic> json) {
    return MaintenanceIntervention(
      tipoIntervencion: json['TipoIntervencion']?.toString() ?? '',
      id: json['Id']?.toString() ?? '',
      codigoActivo: json['CodigoActivo']?.toString() ?? '',
      nombreActivo: json['NombreActivo']?.toString() ?? '',
      nivelActivo: json['NivelActivo']?.toString() ?? '',
      fecha: DateTime.tryParse(json['Fecha']?.toString() ?? '') ?? DateTime.now(),
      titulo: json['Titulo']?.toString() ?? '',
      descripcion: json['Descripcion']?.toString() ?? '',
      estado: json['Estado']?.toString() ?? '',
      severidadOPrioridad: json['SeveridadOPrioridad']?.toString(),
      horasReales: (json['HorasReales'] as num?)?.toDouble(),
      asignadoA: json['AsignadoA']?.toString(),
      responsable: json['Responsable']?.toString(),
      ordenTrabajoVinculadaId: json['OrdenTrabajoVinculadaId']?.toString(),
    );
  }
}

class PartReplacementStat {
  const PartReplacementStat({
    required this.repuesto,
    required this.unidad,
    required this.cantidadTotalConsumida,
    required this.vecesReemplazado,
    this.primerReemplazo,
    this.ultimoReemplazo,
    this.diasPromedioEntreReemplazos,
  });

  final String repuesto;
  final String unidad;
  final double cantidadTotalConsumida;
  final int vecesReemplazado;
  final DateTime? primerReemplazo;
  final DateTime? ultimoReemplazo;
  final double? diasPromedioEntreReemplazos;

  factory PartReplacementStat.fromJson(Map<String, dynamic> json) {
    return PartReplacementStat(
      repuesto: json['Repuesto']?.toString() ?? '',
      unidad: json['Unidad']?.toString() ?? 'UND',
      cantidadTotalConsumida: (json['CantidadTotalConsumida'] as num?)?.toDouble() ?? 0.0,
      vecesReemplazado: (json['VecesReemplazado'] as num?)?.toInt() ?? 0,
      primerReemplazo: DateTime.tryParse(json['PrimerReemplazo']?.toString() ?? ''),
      ultimoReemplazo: DateTime.tryParse(json['UltimoReemplazo']?.toString() ?? ''),
      diasPromedioEntreReemplazos: (json['DiasPromedioEntreReemplazos'] as num?)?.toDouble(),
    );
  }
}

class SeasonalityStat {
  const SeasonalityStat({
    required this.anio,
    required this.mesNumero,
    required this.nombreMes,
    required this.totalAverias,
    required this.averiasBajas,
    required this.averiasMedias,
    required this.averiasAltas,
    required this.averiasCriticas,
    required this.totalOrdenesTrabajo,
    required this.otsPreventivas,
    required this.otsCorrectivas,
    required this.horasTotalesTaller,
    required this.horasParoFallaOperacion,
  });

  final int anio;
  final int mesNumero;
  final String nombreMes;
  final int totalAverias;
  final int averiasBajas;
  final int averiasMedias;
  final int averiasAltas;
  final int averiasCriticas;
  final int totalOrdenesTrabajo;
  final int otsPreventivas;
  final int otsCorrectivas;
  final double horasTotalesTaller;
  final double horasParoFallaOperacion;

  /// Tiempo Medio de Reparación (MTTR) en horas para el mes.
  /// Mide el promedio de horas de taller invertidas por avería o reparación.
  double get mttrHoras {
    if (totalAverias > 0) {
      return horasTotalesTaller / totalAverias;
    }
    if (otsCorrectivas > 0) {
      return horasTotalesTaller / otsCorrectivas;
    }
    return 0.0;
  }

  factory SeasonalityStat.fromJson(Map<String, dynamic> json) {
    return SeasonalityStat(
      anio: (json['Anio'] as num?)?.toInt() ?? DateTime.now().year,
      mesNumero: (json['MesNumero'] as num?)?.toInt() ?? 1,
      nombreMes: json['NombreMes']?.toString() ?? '',
      totalAverias: (json['TotalAverias'] as num?)?.toInt() ?? 0,
      averiasBajas: (json['AveriasBajas'] as num?)?.toInt() ?? 0,
      averiasMedias: (json['AveriasMedias'] as num?)?.toInt() ?? 0,
      averiasAltas: (json['AveriasAltas'] as num?)?.toInt() ?? 0,
      averiasCriticas: (json['AveriasCriticas'] as num?)?.toInt() ?? 0,
      totalOrdenesTrabajo: (json['TotalOrdenesTrabajo'] as num?)?.toInt() ?? 0,
      otsPreventivas: (json['OTsPreventivas'] as num?)?.toInt() ?? 0,
      otsCorrectivas: (json['OTsCorrectivas'] as num?)?.toInt() ?? 0,
      horasTotalesTaller: (json['HorasTotalesTaller'] as num?)?.toDouble() ?? 0.0,
      horasParoFallaOperacion: (json['HorasParoFallaOperacion'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TopFailureAsset {
  const TopFailureAsset({
    required this.codigoActivo,
    required this.nombreActivo,
    required this.nivel,
    required this.areaId,
    required this.nombreArea,
    required this.totalAverias,
    required this.averiasCriticas,
    required this.otsCorrectivas,
    required this.horasTallerInvertidas,
    required this.porcentajeDelTotalFallas,
  });

  final String codigoActivo;
  final String nombreActivo;
  final String nivel;
  final String areaId;
  final String nombreArea;
  final int totalAverias;
  final int averiasCriticas;
  final int otsCorrectivas;
  final double horasTallerInvertidas;
  final double porcentajeDelTotalFallas;

  factory TopFailureAsset.fromJson(Map<String, dynamic> json) {
    return TopFailureAsset(
      codigoActivo: json['CodigoActivo']?.toString() ?? '',
      nombreActivo: json['NombreActivo']?.toString() ?? '',
      nivel: json['Nivel']?.toString() ?? '',
      areaId: json['AreaId']?.toString() ?? '',
      nombreArea: json['NombreArea']?.toString() ?? '',
      totalAverias: (json['TotalAverias'] as num?)?.toInt() ?? 0,
      averiasCriticas: (json['AveriasCriticas'] as num?)?.toInt() ?? 0,
      otsCorrectivas: (json['OTsCorrectivas'] as num?)?.toInt() ?? 0,
      horasTallerInvertidas: (json['HorasTallerInvertidas'] as num?)?.toDouble() ?? 0.0,
      porcentajeDelTotalFallas: (json['PorcentajeDelTotalFallas'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OeeGeneralRecord {
  const OeeGeneralRecord({
    required this.codigoActivo,
    required this.nombreActivo,
    required this.areaId,
    required this.nombreArea,
    required this.diasConReporte,
    required this.totalHorasJornada,
    required this.totalHorasOperacion,
    required this.totalParoFalla,
    required this.totalParoMantenimiento,
    required this.disponibilidadPct,
    required this.rendimientoPct,
    required this.calidadPct,
    required this.oeePct,
  });

  final String codigoActivo;
  final String nombreActivo;
  final String areaId;
  final String nombreArea;
  final int diasConReporte;
  final double totalHorasJornada;
  final double totalHorasOperacion;
  final double totalParoFalla;
  final double totalParoMantenimiento;
  final double disponibilidadPct;
  final double rendimientoPct;
  final double calidadPct;
  final double oeePct;

  factory OeeGeneralRecord.fromJson(Map<String, dynamic> json) {
    return OeeGeneralRecord(
      codigoActivo: json['CodigoActivo']?.toString() ?? '',
      nombreActivo: json['NombreActivo']?.toString() ?? '',
      areaId: json['AreaId']?.toString() ?? '',
      nombreArea: json['NombreArea']?.toString() ?? '',
      diasConReporte: (json['DiasConReporte'] as num?)?.toInt() ?? 0,
      totalHorasJornada: (json['TotalHorasJornada'] as num?)?.toDouble() ?? 0.0,
      totalHorasOperacion: (json['TotalHorasOperacion'] as num?)?.toDouble() ?? 0.0,
      totalParoFalla: (json['TotalParoFalla'] as num?)?.toDouble() ?? 0.0,
      totalParoMantenimiento: (json['TotalParoMantenimiento'] as num?)?.toDouble() ?? 0.0,
      disponibilidadPct: (json['DisponibilidadPct'] as num?)?.toDouble() ?? 0.0,
      rendimientoPct: (json['RendimientoPct'] as num?)?.toDouble() ?? 100.0,
      calidadPct: (json['CalidadPct'] as num?)?.toDouble() ?? 100.0,
      oeePct: (json['OeePct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
