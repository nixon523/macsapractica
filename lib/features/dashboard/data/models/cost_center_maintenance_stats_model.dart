import '../../domain/entities/cost_center_maintenance_stats.dart';

class CostCenterMaintenanceStatsModel extends CostCenterMaintenanceStats {
  const CostCenterMaintenanceStatsModel({
    required super.costCenter,
    required super.areaId,
    required super.areaName,
    required super.totalMaintenance,
    required super.completed,
    required super.inProgress,
    required super.cancelled,
    required super.corrective,
    required super.preventive,
    required super.predictive,
    required super.improvement,
    required super.otherTypes,
    required super.totalRealHours,
    required super.totalEstimatedHours,
  });

  factory CostCenterMaintenanceStatsModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val?.toString() ?? '') ?? 0;
    }

    double parseDouble(dynamic val) {
      if (val is double) return val;
      if (val is num) return val.toDouble();
      return double.tryParse(val?.toString() ?? '') ?? 0.0;
    }

    return CostCenterMaintenanceStatsModel(
      costCenter: (json['costCenter'] ?? json['CentroCosto'] ?? '').toString(),
      areaId: (json['areaId'] ?? json['AreaId'] ?? '').toString(),
      areaName: (json['areaName'] ?? json['Nombre'] ?? json['NombreArea'] ?? '').toString(),
      totalMaintenance: parseInt(json['totalMaintenance'] ?? json['TotalMantenimientos']),
      completed: parseInt(json['completed'] ?? json['Completados']),
      inProgress: parseInt(json['inProgress'] ?? json['EnProceso']),
      cancelled: parseInt(json['cancelled'] ?? json['Canceladas']),
      corrective: parseInt(json['corrective'] ?? json['Correctivos']),
      preventive: parseInt(json['preventive'] ?? json['Preventivos']),
      predictive: parseInt(json['predictive'] ?? json['Predictivos']),
      improvement: parseInt(json['improvement'] ?? json['Mejoras']),
      otherTypes: parseInt(json['otherTypes'] ?? json['OtrosTipos']),
      totalRealHours: parseDouble(json['totalRealHours'] ?? json['HorasRealesTotales']),
      totalEstimatedHours: parseDouble(json['totalEstimatedHours'] ?? json['HorasEstimadasTotales']),
    );
  }
}

class CostCenterMaintenanceDetailModel extends CostCenterMaintenanceDetail {
  const CostCenterMaintenanceDetailModel({
    required super.workOrderId,
    required super.assetCode,
    required super.assetName,
    required super.areaId,
    required super.areaName,
    required super.costCenter,
    required super.description,
    required super.status,
    required super.priority,
    super.assignedTo,
    super.estimatedHours,
    super.actualHours,
    super.createdAt,
    super.scheduledDate,
    super.reportId,
    super.preventiveScheduleId,
    required super.mainMaintenanceType,
    super.workTypesText,
  });

  factory CostCenterMaintenanceDetailModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is double) return val;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return CostCenterMaintenanceDetailModel(
      workOrderId: (json['workOrderId'] ?? json['OrdenTrabajoId'] ?? '').toString(),
      assetCode: (json['assetCode'] ?? json['CodigoActivo'] ?? '').toString(),
      assetName: (json['assetName'] ?? json['NombreActivo'] ?? '').toString(),
      areaId: (json['areaId'] ?? json['AreaId'] ?? '').toString(),
      areaName: (json['areaName'] ?? json['NombreArea'] ?? json['Nombre'] ?? '').toString(),
      costCenter: (json['costCenter'] ?? json['CentroCosto'] ?? '').toString(),
      description: (json['description'] ?? json['Descripcion'] ?? '').toString(),
      status: (json['status'] ?? json['Estado'] ?? '').toString(),
      priority: (json['priority'] ?? json['Prioridad'] ?? 'media').toString(),
      assignedTo: json['assignedTo'] ?? json['AsignadoA'],
      estimatedHours: parseDouble(json['estimatedHours'] ?? json['HorasEstimadas']),
      actualHours: parseDouble(json['actualHours'] ?? json['HorasReales']),
      createdAt: parseDate(json['createdAt'] ?? json['CreadoEn']),
      scheduledDate: parseDate(json['scheduledDate'] ?? json['FechaProgramada']),
      reportId: json['reportId'] ?? json['ReporteId'],
      preventiveScheduleId: json['preventiveScheduleId'] ?? json['PlanPreventivoId'],
      mainMaintenanceType: (json['mainMaintenanceType'] ?? 'other').toString(),
      workTypesText: json['workTypesText'] ?? json['TiposTrabajoConcatenados'],
    );
  }
}
