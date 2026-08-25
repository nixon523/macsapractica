enum WorkOrderStatus { pending, inProgress, completed, cancelled }

enum WorkOrderPriority { low, medium, high }

/// Material, Refacción, Equipo o Herramienta registrada en la Orden de Trabajo.
class WorkOrderMaterial {
  const WorkOrderMaterial({
    required this.description,
    required this.quantity,
    this.unit = 'pz',
  });

  final String description;
  final double quantity;
  final String unit;

  Map<String, dynamic> toMap() => {
        'description': description,
        'quantity': quantity,
        'unit': unit,
      };

  factory WorkOrderMaterial.fromMap(Map<String, dynamic> map) {
    return WorkOrderMaterial(
      description: map['description'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] ?? 'pz',
    );
  }
}

/// Entidad que representa la Orden de Trabajo de Mantenimiento (Formato REG.GMC-MTN-001).
class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.assetId,
    required this.assetName,
    required this.description,
    required this.status,
    this.correlativeNumber,
    this.areaId,
    this.areaName,
    this.requestedWorkTypes = const [],
    this.priority = WorkOrderPriority.medium,
    this.assignedTo,
    this.assignedStaffCount,
    this.estimatedHours,
    this.actualHours,
    this.materials = const [],
    this.workDoneDescription,
    this.isCompleted,
    this.unfulfillmentReason,
    this.reprogramDate,
    this.accHaccpResponsible,
    this.maintenanceResponsible,
    this.areaHeadResponsible,
    this.maintenanceHeadResponsible,
    this.scheduledDate,
    this.reportId,
    this.createdByUserId,
    this.createdByUserName,
    this.createdAt,
  });

  final String id;
  final String? correlativeNumber;
  final String assetId;
  final String assetName;
  final String? areaId;
  final String? areaName;
  final String description;
  final WorkOrderStatus status;
  final WorkOrderPriority priority;

  /// Tipos de trabajo solicitados (ej. 'electric', 'mechanical', 'urgency', 'refrigeration', 'plumbing', 'preventive', 'corrective', 'scheduled')
  final List<String> requestedWorkTypes;

  final String? assignedTo;
  final int? assignedStaffCount;
  final double? estimatedHours;
  final double? actualHours;

  /// Material, Equipo, Herramienta y/o Refacciones a utilizar
  final List<WorkOrderMaterial> materials;

  /// Descripción detallada del trabajo realizado y observaciones
  final String? workDoneDescription;

  /// Cumplimiento y/o reprogramación
  final bool? isCompleted;
  final String? unfulfillmentReason;
  final DateTime? reprogramDate;

  /// Responsables de firma
  final String? accHaccpResponsible;
  final String? maintenanceResponsible;
  final String? areaHeadResponsible;
  final String? maintenanceHeadResponsible;

  final DateTime? scheduledDate;

  /// Reporte de avería que dio origen a esta OT (si existe)
  final String? reportId;

  final String? createdByUserId;
  final String? createdByUserName;
  final DateTime? createdAt;

  bool get isOpen =>
      status == WorkOrderStatus.pending ||
      status == WorkOrderStatus.inProgress;

  String get displayCorrelative => correlativeNumber ?? id;

  String get statusLabel => switch (status) {
        WorkOrderStatus.pending => 'Pendiente',
        WorkOrderStatus.inProgress => 'En Progreso',
        WorkOrderStatus.completed => 'Completada',
        WorkOrderStatus.cancelled => 'Cancelada',
      };

  String get priorityLabel => switch (priority) {
        WorkOrderPriority.low => 'Baja',
        WorkOrderPriority.medium => 'Media',
        WorkOrderPriority.high => 'Alta',
      };

  WorkOrder copyWith({
    String? id,
    String? correlativeNumber,
    String? assetId,
    String? assetName,
    String? areaId,
    String? areaName,
    String? description,
    WorkOrderStatus? status,
    WorkOrderPriority? priority,
    List<String>? requestedWorkTypes,
    String? assignedTo,
    int? assignedStaffCount,
    double? estimatedHours,
    double? actualHours,
    List<WorkOrderMaterial>? materials,
    String? workDoneDescription,
    bool? isCompleted,
    String? unfulfillmentReason,
    DateTime? reprogramDate,
    String? accHaccpResponsible,
    String? maintenanceResponsible,
    String? areaHeadResponsible,
    String? maintenanceHeadResponsible,
    DateTime? scheduledDate,
    String? reportId,
    String? createdByUserId,
    String? createdByUserName,
    DateTime? createdAt,
  }) {
    return WorkOrder(
      id: id ?? this.id,
      correlativeNumber: correlativeNumber ?? this.correlativeNumber,
      assetId: assetId ?? this.assetId,
      assetName: assetName ?? this.assetName,
      areaId: areaId ?? this.areaId,
      areaName: areaName ?? this.areaName,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      requestedWorkTypes: requestedWorkTypes ?? this.requestedWorkTypes,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedStaffCount: assignedStaffCount ?? this.assignedStaffCount,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      materials: materials ?? this.materials,
      workDoneDescription: workDoneDescription ?? this.workDoneDescription,
      isCompleted: isCompleted ?? this.isCompleted,
      unfulfillmentReason: unfulfillmentReason ?? this.unfulfillmentReason,
      reprogramDate: reprogramDate ?? this.reprogramDate,
      accHaccpResponsible: accHaccpResponsible ?? this.accHaccpResponsible,
      maintenanceResponsible:
          maintenanceResponsible ?? this.maintenanceResponsible,
      areaHeadResponsible: areaHeadResponsible ?? this.areaHeadResponsible,
      maintenanceHeadResponsible:
          maintenanceHeadResponsible ?? this.maintenanceHeadResponsible,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      reportId: reportId ?? this.reportId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserName: createdByUserName ?? this.createdByUserName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
