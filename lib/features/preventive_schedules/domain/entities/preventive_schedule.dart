enum ScheduleFrequency {
  daily('Diaria', 1),
  weekly('Semanal', 7),
  biweekly('Quincenal', 15),
  monthly('Mensual', 30),
  bimonthly('Bimestral', 60),
  quarterly('Trimestral', 90),
  semiannual('Semestral', 180),
  annual('Anual', 365),
  biannual('Bianual', 730);

  const ScheduleFrequency(this.label, this.days);
  final String label;
  final int days;

  /// Frecuencias permitidas para el plan de mantenimiento a nivel general de equipo
  static const List<ScheduleFrequency> globalFrequencies = [
    ScheduleFrequency.monthly,
    ScheduleFrequency.bimonthly,
    ScheduleFrequency.quarterly,
    ScheduleFrequency.semiannual,
    ScheduleFrequency.annual,
    ScheduleFrequency.biannual,
  ];

  static ScheduleFrequency fromString(String? value) {
    if (value == null || value.trim().isEmpty) return ScheduleFrequency.monthly;
    final lower = value.trim().toLowerCase();
    return ScheduleFrequency.values.firstWhere(
      (e) => e.name.toLowerCase() == lower || e.label.toLowerCase() == lower,
      orElse: () => ScheduleFrequency.monthly,
    );
  }

  DateTime calculateNextDate(DateTime fromDate) {
    return fromDate.add(Duration(days: days));
  }
}

enum ScheduleStatus {
  active('Activo'),
  paused('Pausado'),
  completed('Completado');

  const ScheduleStatus(this.label);
  final String label;
}

enum PreventiveAlertLevel {
  overdue('Vencido', 0),
  urgent('Urgente (<48h)', 1),
  upcoming('Próximo (3-7d)', 2),
  onSchedule('Al día (>7d)', 3);

  const PreventiveAlertLevel(this.label, this.priorityOrder);
  final String label;
  final int priorityOrder;
}

class PreventiveMaterial {
  const PreventiveMaterial({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  final String name;
  final double quantity;
  final String unit;

  factory PreventiveMaterial.fromMap(Map<String, dynamic> map) {
    return PreventiveMaterial(
      name: (map['name'] ?? map['nombre'] ?? '').toString(),
      quantity: (map['quantity'] ?? map['cantidad'] as num?)?.toDouble() ?? 1.0,
      unit: (map['unit'] ?? map['unidad'] ?? 'pza').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nombre': name,
      'quantity': quantity,
      'cantidad': quantity,
      'unit': unit,
      'unidad': unit,
    };
  }
}

/// Actividad preventiva programada para un componente hijo (subequipo, parte)
class PreventiveChildActivity {
  const PreventiveChildActivity({
    this.id,
    required this.childAssetId,
    required this.childAssetName,
    this.childAssetLevel = 'subEquipment',
    required this.description,
    this.frequencyInterval = 1,
    this.frequencyUnit = 'meses',
    this.estimatedHours,
    required this.startDate,
    required this.nextDate,
    this.lastExecutionDate,
    this.status = 'active',
    this.materials = const [],
  });

  final int? id;
  final String childAssetId;
  final String childAssetName;
  final String childAssetLevel;
  final String description;
  final int frequencyInterval;
  final String frequencyUnit;
  final double? estimatedHours;
  final DateTime startDate;
  final DateTime nextDate;
  final DateTime? lastExecutionDate;
  final String status;
  final List<PreventiveMaterial> materials;

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(nextDate.year, nextDate.month, nextDate.day);
    return target.difference(today).inDays;
  }

  bool get isOverdue => daysRemaining < 0;

  PreventiveAlertLevel get alertLevel {
    if (isOverdue) return PreventiveAlertLevel.overdue;
    if (daysRemaining <= 2) return PreventiveAlertLevel.urgent;
    if (daysRemaining <= 7) return PreventiveAlertLevel.upcoming;
    return PreventiveAlertLevel.onSchedule;
  }

  String get frequencyLabel => 'Cada $frequencyInterval $frequencyUnit';

  factory PreventiveChildActivity.fromMap(Map<String, dynamic> map) {
    DateTime parseDt(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    final rawMaterials = map['materiales'] ?? map['materials'];
    final mats = <PreventiveMaterial>[];
    if (rawMaterials is List) {
      for (final m in rawMaterials) {
        if (m is Map) mats.add(PreventiveMaterial.fromMap(Map<String, dynamic>.from(m)));
      }
    }

    return PreventiveChildActivity(
      id: map['actividadId'] is int ? map['actividadId'] as int : int.tryParse('${map['actividadId']}'),
      childAssetId: (map['codigoActivoHijo'] ?? map['childAssetId'] ?? '').toString(),
      childAssetName: (map['nombreActivoHijo'] ?? map['childAssetName'] ?? '').toString(),
      childAssetLevel: (map['nivelActivoHijo'] ?? map['childAssetLevel'] ?? 'subEquipment').toString(),
      description: (map['descripcionActividad'] ?? map['description'] ?? map['tarea'] ?? '').toString(),
      frequencyInterval: (map['intervaloFrecuencia'] ?? map['frequencyInterval'] as num?)?.toInt() ?? 1,
      frequencyUnit: (map['unidadFrecuencia'] ?? map['frequencyUnit'] ?? 'meses').toString(),
      estimatedHours: (map['horasEstimadas'] ?? map['estimatedHours'] as num?)?.toDouble(),
      startDate: parseDt(map['fechaInicio'] ?? map['startDate']),
      nextDate: parseDt(map['proximaFecha'] ?? map['nextDate']),
      lastExecutionDate: map['fechaUltimaEjecucion'] != null ? parseDt(map['fechaUltimaEjecucion']) : null,
      status: (map['estado'] ?? map['status'] ?? 'active').toString(),
      materials: mats,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'actividadId': id,
      'codigoActivoHijo': childAssetId,
      'nombreActivoHijo': childAssetName,
      'nivelActivoHijo': childAssetLevel,
      'descripcionActividad': description,
      'intervaloFrecuencia': frequencyInterval,
      'unidadFrecuencia': frequencyUnit,
      if (estimatedHours != null) 'horasEstimadas': estimatedHours,
      'fechaInicio': startDate.toIso8601String(),
      'proximaFecha': nextDate.toIso8601String(),
      if (lastExecutionDate != null) 'fechaUltimaEjecucion': lastExecutionDate?.toIso8601String(),
      'estado': status,
      'materiales': materials.map((m) => m.toMap()).toList(),
    };
  }
}

/// Plan Preventivo Maestro para el Equipo Principal (Padre)
class PreventiveSchedule {
  const PreventiveSchedule({
    required this.id,
    this.title = '',
    required this.assetId,
    this.assetName = '',
    required this.areaId,
    this.areaName = '',
    required this.maintenanceType,
    required this.frequency,
    this.frequencyInterval = 1,
    this.frequencyUnit = 'meses',
    this.description = '',
    this.materials = const [],
    this.activities = const [],
    this.estimatedHours,
    required this.startDate,
    required this.nextDate,
    this.lastCompleted,
    this.lastWorkOrderId,
    required this.status,
    this.notes,
    this.createdByUserId,
    this.createdByUserName,
    this.createdAt,
    this.amendmentDocNumber,
    this.amendedBy,
    this.amendedAt,
    this.amendmentReason,
  });

  final String id;
  final String title;
  final String assetId;
  final String assetName;
  final String areaId;
  final String areaName;
  final String maintenanceType;
  final ScheduleFrequency frequency;
  final int frequencyInterval;
  final String frequencyUnit;
  final String description;
  final List<PreventiveMaterial> materials;
  final List<PreventiveChildActivity> activities;
  final double? estimatedHours;
  final DateTime startDate;
  final DateTime nextDate;
  final DateTime? lastCompleted;
  final String? lastWorkOrderId;
  final ScheduleStatus status;
  final String? notes;

  final String? createdByUserId;
  final String? createdByUserName;
  final DateTime? createdAt;

  final String? amendmentDocNumber;
  final String? amendedBy;
  final DateTime? amendedAt;
  final String? amendmentReason;

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(nextDate.year, nextDate.month, nextDate.day);
    return target.difference(today).inDays;
  }

  bool get isOverdue => daysRemaining < 0;

  bool get canGenerateWorkOrder => isOverdue || daysRemaining <= 7;

  PreventiveAlertLevel get alertLevel {
    if (isOverdue) return PreventiveAlertLevel.overdue;
    if (daysRemaining <= 2) return PreventiveAlertLevel.urgent;
    if (daysRemaining <= 7) return PreventiveAlertLevel.upcoming;
    return PreventiveAlertLevel.onSchedule;
  }

  /// Próximas actividades de componentes que vencen en el mes de la fecha indicada
  List<PreventiveChildActivity> activitiesDueInMonth(DateTime monthDate) {
    return activities.where((act) {
      return act.status == 'active' &&
          act.nextDate.year == monthDate.year &&
          act.nextDate.month == monthDate.month;
    }).toList();
  }
}
