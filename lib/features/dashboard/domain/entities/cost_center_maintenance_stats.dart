class CostCenterMaintenanceStats {
  const CostCenterMaintenanceStats({
    required this.costCenter,
    required this.areaId,
    required this.areaName,
    required this.totalMaintenance,
    required this.completed,
    required this.inProgress,
    required this.cancelled,
    required this.corrective,
    required this.preventive,
    required this.predictive,
    required this.improvement,
    required this.otherTypes,
    required this.totalRealHours,
    required this.totalEstimatedHours,
  });

  final String costCenter;
  final String areaId;
  final String areaName;
  final int totalMaintenance;
  final int completed;
  final int inProgress;
  final int cancelled;
  final int corrective;
  final int preventive;
  final int predictive;
  final int improvement;
  final int otherTypes;
  final double totalRealHours;
  final double totalEstimatedHours;
}

class CostCenterMaintenanceDetail {
  const CostCenterMaintenanceDetail({
    required this.workOrderId,
    required this.assetCode,
    required this.assetName,
    required this.areaId,
    required this.areaName,
    required this.costCenter,
    required this.description,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.estimatedHours,
    this.actualHours,
    this.createdAt,
    this.scheduledDate,
    this.reportId,
    this.preventiveScheduleId,
    required this.mainMaintenanceType,
    this.workTypesText,
  });

  final String workOrderId;
  final String assetCode;
  final String assetName;
  final String areaId;
  final String areaName;
  final String costCenter;
  final String description;
  final String status;
  final String priority;
  final String? assignedTo;
  final double? estimatedHours;
  final double? actualHours;
  final DateTime? createdAt;
  final DateTime? scheduledDate;
  final String? reportId;
  final String? preventiveScheduleId;
  final String mainMaintenanceType;
  final String? workTypesText;
}
