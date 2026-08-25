enum ScheduleFrequency {
  daily('Diaria', 1),
  weekly('Semanal', 7),
  biweekly('Quincenal', 15),
  monthly('Mensual', 30),
  bimonthly('Bimestral', 60),
  quarterly('Trimestral', 90),
  semiannual('Semestral', 180),
  annual('Anual', 365);

  const ScheduleFrequency(this.label, this.days);
  final String label;
  final int days;

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
      name: map['name'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] ?? 'pza',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }
}

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
    this.description = '',
    this.materials = const [],
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
  final String description;
  final List<PreventiveMaterial> materials;
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

  /// Solo se permite generar la Orden de Trabajo preventiva cuando se alcanza la
  /// ventana de atención programada (≤ 7 días de anticipación o vencido).
  bool get canGenerateWorkOrder => isOverdue || daysRemaining <= 7;

  PreventiveAlertLevel get alertLevel {
    if (isOverdue) return PreventiveAlertLevel.overdue;
    if (daysRemaining <= 2) return PreventiveAlertLevel.urgent;
    if (daysRemaining <= 7) return PreventiveAlertLevel.upcoming;
    return PreventiveAlertLevel.onSchedule;
  }
}
