import 'dart:convert';

import '../../../../core/utils/text_sanitizer.dart';
import '../../domain/entities/work_order.dart';

class WorkOrderModel extends WorkOrder {
  const WorkOrderModel({
    required super.id,
    super.correlativeNumber,
    required super.assetId,
    required super.assetName,
    super.areaId,
    super.areaName,
    required super.description,
    required super.status,
    super.priority,
    super.requestedWorkTypes,
    super.assignedTo,
    super.assignedStaffCount,
    super.estimatedHours,
    super.actualHours,
    super.materials,
    super.workDoneDescription,
    super.isCompleted,
    super.unfulfillmentReason,
    super.reprogramDate,
    super.accHaccpResponsible,
    super.maintenanceResponsible,
    super.areaHeadResponsible,
    super.maintenanceHeadResponsible,
    super.scheduledDate,
    super.reportId,
    super.preventiveScheduleId,
    super.createdByUserId,
    super.createdByUserName,
    super.createdAt,
  });

  factory WorkOrderModel.fromJson(Map<String, dynamic> map, [String? docId]) {
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
        (map['correlativeNumber'] ??
                map['WorkOrderNumber'] ??
                map['workOrderId'] ??
                map['WorkOrderId'] ??
                map['id'] ??
                '')
            ?.toString() ??
        '';

    final correlativeNumber = (map['correlativeNumber'] ??
            map['WorkOrderNumber'] ??
            map['workOrderNumber'] ??
            id)
        ?.toString();

    final statusStr = (map['status'] ?? map['Status'] ?? 'pending').toString();
    final status = WorkOrderStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => WorkOrderStatus.pending,
    );

    final priorityStr =
        (map['priority'] ?? map['Priority'] ?? 'medium').toString();
    final priority = WorkOrderPriority.values.firstWhere(
      (e) => e.name.toLowerCase() == priorityStr.toLowerCase(),
      orElse: () => WorkOrderPriority.medium,
    );

    // Parse materials
    List<WorkOrderMaterial> materialsList = [];
    final rawMaterials = map['materials'] ??
        map['Materials'] ??
        map['MaterialsJson'] ??
        map['materialsJson'];
    if (rawMaterials is List) {
      materialsList = rawMaterials
          .whereType<Map>()
          .map((m) => WorkOrderMaterial.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } else if (rawMaterials is String && rawMaterials.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMaterials);
        if (decoded is List) {
          materialsList = decoded
              .whereType<Map>()
              .map((m) => WorkOrderMaterial.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }
      } catch (_) {}
    }

    // Parse work types
    List<String> workTypesList = [];
    final rawTypes = map['requestedWorkTypes'] ??
        map['workTypes'] ??
        map['WorkTypes'] ??
        map['WorkTypesJson'] ??
        map['WorkTypesCsv'] ??
        map['workTypesCsv'];
    if (rawTypes is List) {
      workTypesList = rawTypes
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawTypes is String && rawTypes.isNotEmpty) {
      final trimmed = rawTypes.trim();
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            workTypesList = decoded
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } catch (_) {}
      } else {
        workTypesList = trimmed
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    String? prevPlanId = (map['preventiveScheduleId'] ??
            map['PreventiveScheduleId'] ??
            map['planPreventivoId'] ??
            map['PlanPreventivoId'])
        ?.toString();
    if (prevPlanId == null || prevPlanId.isEmpty || prevPlanId == 'null') {
      final desc = (map['description'] ?? map['Description'] ?? '').toString();
      final match = RegExp(r'Plan\s+([A-Z0-9-]+)', caseSensitive: false).firstMatch(desc);
      if (match != null) {
        prevPlanId = match.group(1);
      } else {
        prevPlanId = null;
      }
    }

    if (prevPlanId != null &&
        prevPlanId.isNotEmpty &&
        !workTypesList.contains('preventive')) {
      workTypesList.add('preventive');
    }

    String? repId = (map['reportId'] ?? map['ReportId'])?.toString();
    if (repId == 'null' || repId == '') repId = null;
    if (repId == null) {
      final desc = (map['description'] ?? map['Description'] ?? '').toString();
      final match = RegExp(r'Aver[ií]a\s+#?(\d+)', caseSensitive: false).firstMatch(desc);
      if (match != null) {
        repId = match.group(1);
      }
    }
    if (repId != null &&
        repId.isNotEmpty &&
        !workTypesList.contains('corrective')) {
      workTypesList.add('corrective');
    }

    final isCompletedVal = map['isCompleted'] ?? map['IsCompleted'];

    return WorkOrderModel(
      id: id,
      correlativeNumber: correlativeNumber,
      assetId: (map['assetId'] ?? map['AssetCode'] ?? map['assetCode'] ?? '')
          .toString(),
      assetName: (map['assetName'] ?? map['AssetName'] ?? '').toString(),
      areaId: (map['areaId'] ?? map['AreaId'])?.toString(),
      areaName: (map['areaName'] ?? map['AreaName'])?.toString(),
      description: TextSanitizer.cleanDescription((map['description'] ?? map['Description'] ?? '').toString()),
      status: status,
      priority: priority,
      requestedWorkTypes: workTypesList,
      assignedTo: (map['assignedTo'] ?? map['AssignedTo'])?.toString(),
      assignedStaffCount: (map['assignedStaffCount'] ?? map['AssignedStaffCount']) is int
          ? (map['assignedStaffCount'] ?? map['AssignedStaffCount']) as int
          : int.tryParse((map['assignedStaffCount'] ?? map['AssignedStaffCount'])?.toString() ?? ''),
      estimatedHours: (map['estimatedHours'] ?? map['EstimatedHours'] as num?)?.toDouble(),
      actualHours: (map['actualHours'] ?? map['ActualHours'] as num?)?.toDouble(),
      materials: materialsList,
      workDoneDescription: (map['workDoneDescription'] ?? map['WorkDoneDescription']) != null
          ? TextSanitizer.cleanDescription((map['workDoneDescription'] ?? map['WorkDoneDescription']).toString())
          : null,
      isCompleted: isCompletedVal is bool
          ? isCompletedVal
          : (isCompletedVal == 1 ? true : (isCompletedVal == 0 ? false : null)),
      unfulfillmentReason: (map['unfulfillmentReason'] ?? map['UnfulfillmentReason'])?.toString(),
      reprogramDate: parseDate(map['reprogramDate'] ?? map['ReprogramDate']),
      accHaccpResponsible: (map['accHaccpResponsible'] ?? map['AccHaccpResponsible'])?.toString(),
      maintenanceResponsible: (map['maintenanceResponsible'] ?? map['MaintenanceResponsible'])?.toString(),
      areaHeadResponsible: (map['areaHeadResponsible'] ?? map['AreaHeadResponsible'])?.toString(),
      maintenanceHeadResponsible: (map['maintenanceHeadResponsible'] ?? map['MaintenanceHeadResponsible'])?.toString(),
      scheduledDate: parseDate(map['scheduledDate'] ?? map['ScheduledDate']),
      reportId: repId,
      preventiveScheduleId: prevPlanId,
      createdByUserId: (map['createdByUserId'] ?? map['CreatedByUserId'])?.toString(),
      createdByUserName: (map['createdByUserName'] ?? map['CreatedByUserName'])?.toString(),
      createdAt: parseDate(map['createdAt'] ?? map['CreatedAt']),
    );
  }

  factory WorkOrderModel.fromFirestore(
      Map<String, dynamic> map, String docId) {
    return WorkOrderModel.fromJson(map, docId);
  }

  Map<String, dynamic> toJson() {
    return {
      'correlativeNumber': correlativeNumber ?? id,
      'assetCode': assetId,
      'assetName': assetName,
      'areaId': areaId,
      'areaName': areaName,
      'description': description,
      'priority': priority.name,
      'status': status.name,
      'requestedWorkTypes': requestedWorkTypes,
      'assignedTo': assignedTo,
      'assignedStaffCount': assignedStaffCount,
      'estimatedHours': estimatedHours,
      'actualHours': actualHours,
      'materials': materials.map((m) => m.toMap()).toList(),
      'workDoneDescription': workDoneDescription,
      'isCompleted': isCompleted,
      'unfulfillmentReason': unfulfillmentReason,
      'reprogramDate': reprogramDate?.toIso8601String(),
      'scheduledDate': scheduledDate?.toIso8601String(),
      'reportId': reportId != null ? int.tryParse(reportId!) : null,
      'preventiveScheduleId': preventiveScheduleId,
      'planPreventivoId': preventiveScheduleId,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'correlativeNumber': correlativeNumber ?? id,
      'assetId': assetId,
      'assetName': assetName,
      if (areaId != null) 'areaId': areaId,
      if (areaName != null) 'areaName': areaName,
      'description': description,
      'status': status.name,
      'priority': priority.name,
      'requestedWorkTypes': requestedWorkTypes,
      if (assignedTo != null) 'assignedTo': assignedTo,
      if (assignedStaffCount != null) 'assignedStaffCount': assignedStaffCount,
      if (estimatedHours != null) 'estimatedHours': estimatedHours,
      if (actualHours != null) 'actualHours': actualHours,
      'materials': materials.map((m) => m.toMap()).toList(),
      if (workDoneDescription != null)
        'workDoneDescription': workDoneDescription,
      if (isCompleted != null) 'isCompleted': isCompleted,
      if (unfulfillmentReason != null)
        'unfulfillmentReason': unfulfillmentReason,
      if (reprogramDate != null)
        'reprogramDate': reprogramDate,
      if (accHaccpResponsible != null)
        'accHaccpResponsible': accHaccpResponsible,
      if (maintenanceResponsible != null)
        'maintenanceResponsible': maintenanceResponsible,
      if (areaHeadResponsible != null)
        'areaHeadResponsible': areaHeadResponsible,
      if (maintenanceHeadResponsible != null)
        'maintenanceHeadResponsible': maintenanceHeadResponsible,
      if (scheduledDate != null)
        'scheduledDate': scheduledDate,
      if (reportId != null) 'reportId': reportId,
      if (preventiveScheduleId != null) 'preventiveScheduleId': preventiveScheduleId,
      if (createdByUserId != null) 'createdByUserId': createdByUserId,
      if (createdByUserName != null) 'createdByUserName': createdByUserName,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}
