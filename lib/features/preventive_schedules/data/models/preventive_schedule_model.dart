import 'dart:convert';

import '../../domain/entities/preventive_schedule.dart';

class PreventiveScheduleModel extends PreventiveSchedule {
  const PreventiveScheduleModel({
    required super.id,
    super.title,
    required super.assetId,
    super.assetName,
    required super.areaId,
    super.areaName,
    required super.maintenanceType,
    required super.frequency,
    super.description,
    super.materials,
    super.estimatedHours,
    required super.startDate,
    required super.nextDate,
    super.lastCompleted,
    super.lastWorkOrderId,
    required super.status,
    super.notes,
    super.createdByUserId,
    super.createdByUserName,
    super.createdAt,
    super.amendmentDocNumber,
    super.amendedBy,
    super.amendedAt,
    super.amendmentReason,
  });

  factory PreventiveScheduleModel.fromJson(
    Map<String, dynamic> map, [
    String? docId,
  ]) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      try {
        return (d as dynamic).toDate();
      } catch (_) {
        if (d is String) return DateTime.tryParse(d);
      }
      return null;
    }

    final id = docId ??
        (map['scheduleId'] ?? map['ScheduleId'] ?? map['id'] ?? '')
            ?.toString() ??
        '';

    final freqStr =
        (map['frequency'] ?? map['Frequency'] ?? 'monthly').toString();
    final frequency = ScheduleFrequency.fromString(freqStr);

    final statusStr =
        (map['status'] ?? map['Status'] ?? 'active').toString();
    final status = ScheduleStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => ScheduleStatus.active,
    );

    // Parse materials
    List<PreventiveMaterial> materialsList = [];
    final rawMaterials = map['materials'] ??
        map['Materials'] ??
        map['MaterialsJson'] ??
        map['materialsJson'];
    if (rawMaterials is List) {
      materialsList = rawMaterials
          .whereType<Map>()
          .map((m) => PreventiveMaterial.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } else if (rawMaterials is String && rawMaterials.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMaterials);
        if (decoded is List) {
          materialsList = decoded
              .whereType<Map>()
              .map((m) => PreventiveMaterial.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }
      } catch (_) {}
    }

    final startDate =
        parseDate(map['startDate'] ?? map['StartDate']) ?? DateTime.now();
    final nextDate =
        parseDate(map['nextDate'] ?? map['NextDate']) ?? DateTime.now();

    return PreventiveScheduleModel(
      id: id,
      title: (map['title'] ?? map['Title'] ?? '').toString(),
      assetId: (map['assetId'] ?? map['AssetCode'] ?? map['assetCode'] ?? '')
          .toString(),
      assetName: (map['assetName'] ?? map['AssetName'] ?? '').toString(),
      areaId: (map['areaId'] ?? map['AreaId'] ?? '').toString(),
      areaName: (map['areaName'] ?? map['AreaName'] ?? '').toString(),
      maintenanceType:
          (map['maintenanceType'] ?? map['MaintenanceType'] ?? '').toString(),
      frequency: frequency,
      description: (map['description'] ?? map['Description'] ?? '').toString(),
      materials: materialsList,
      estimatedHours: (map['estimatedHours'] ?? map['EstimatedHours'] as num?)?.toDouble(),
      startDate: startDate,
      nextDate: nextDate,
      lastCompleted: parseDate(map['lastCompleted'] ?? map['LastCompleted']),
      lastWorkOrderId:
          (map['lastWorkOrderId'] ?? map['LastWorkOrderId'])?.toString(),
      status: status,
      notes: (map['notes'] ?? map['Notes'])?.toString(),
      createdByUserId:
          (map['createdByUserId'] ?? map['CreatedByUserId'])?.toString(),
      createdByUserName:
          (map['createdByUserName'] ?? map['CreatedByUserName'])?.toString(),
      createdAt: parseDate(map['createdAt'] ?? map['CreatedAt']),
      amendmentDocNumber:
          (map['amendmentDocNumber'] ?? map['AmendmentDocNumber'])?.toString(),
      amendedBy: (map['amendedBy'] ?? map['AmendedBy'])?.toString(),
      amendedAt: parseDate(map['amendedAt'] ?? map['AmendedAt']),
      amendmentReason:
          (map['amendmentReason'] ?? map['AmendmentReason'])?.toString(),
    );
  }

  factory PreventiveScheduleModel.fromFirestore(
    Map<String, dynamic> map,
    String docId,
  ) {
    return PreventiveScheduleModel.fromJson(map, docId);
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'assetCode': assetId,
      'assetName': assetName,
      'areaId': areaId,
      'areaName': areaName,
      'maintenanceType': maintenanceType,
      'frequency': frequency.name,
      'description': description,
      'materials': materials.map((m) => m.toMap()).toList(),
      'estimatedHours': estimatedHours,
      'startDate': startDate.toIso8601String(),
      'nextDate': nextDate.toIso8601String(),
      'lastCompleted': lastCompleted?.toIso8601String(),
      'lastWorkOrderId': lastWorkOrderId,
      'status': status.name,
      'notes': notes,
      'amendmentDocNumber': amendmentDocNumber,
      'amendedBy': amendedBy,
      'amendedAt': amendedAt?.toIso8601String(),
      'amendmentReason': amendmentReason,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'assetId': assetId,
      'assetName': assetName,
      'areaId': areaId,
      'areaName': areaName,
      'maintenanceType': maintenanceType,
      'frequency': frequency.name,
      'description': description,
      'materials': materials.map((m) => m.toMap()).toList(),
      'estimatedHours': estimatedHours,
      'startDate': startDate,
      'nextDate': nextDate,
      'lastCompleted': lastCompleted,
      'lastWorkOrderId': lastWorkOrderId,
      'status': status.name,
      'notes': notes,
      'createdByUserId': createdByUserId,
      'createdByUserName': createdByUserName,
      'createdAt': createdAt,
      'amendmentDocNumber': amendmentDocNumber,
      'amendedBy': amendedBy,
      'amendedAt': amendedAt,
      'amendmentReason': amendmentReason,
    };
  }
}
