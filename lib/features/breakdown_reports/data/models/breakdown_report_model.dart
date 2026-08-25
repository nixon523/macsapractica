import '../../domain/entities/breakdown_report.dart';

class BreakdownReportModel extends BreakdownReport {
  const BreakdownReportModel({
    required super.id,
    required super.assetId,
    required super.assetName,
    required super.areaId,
    required super.description,
    required super.severity,
    required super.reportedByUserId,
    required super.reportedByUserName,
    required super.reportedAt,
    required super.status,
    super.workOrderId,
    super.resolvedByUserId,
    super.resolvedByUserName,
    super.resolvedAt,
    super.rejectionReason,
    super.rejectedByUserId,
    super.rejectedByUserName,
    super.rejectedAt,
  });

  factory BreakdownReportModel.fromJson(
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
        (map['reportId'] ?? map['ReportId'] ?? map['id'] ?? '')?.toString() ??
        '';

    final severityStr =
        (map['severity'] ?? map['Severity'] ?? 'medium').toString();
    final severity = BreakdownSeverity.values.firstWhere(
      (e) => e.name.toLowerCase() == severityStr.toLowerCase(),
      orElse: () => BreakdownSeverity.medium,
    );

    final statusStr =
        (map['status'] ?? map['Status'] ?? 'reported').toString();
    final status = BreakdownReportStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => BreakdownReportStatus.reported,
    );

    return BreakdownReportModel(
      id: id,
      assetId: (map['assetId'] ?? map['AssetCode'] ?? map['assetCode'] ?? '')
          .toString(),
      assetName: (map['assetName'] ?? map['AssetName'] ?? '').toString(),
      areaId: (map['areaId'] ?? map['AreaId'] ?? '').toString(),
      description: (map['description'] ?? map['Description'] ?? '').toString(),
      severity: severity,
      reportedByUserId:
          (map['reportedByUserId'] ?? map['ReportedByUserId'] ?? '')
              .toString(),
      reportedByUserName:
          (map['reportedByUserName'] ?? map['ReportedByUserName'] ?? '')
              .toString(),
      reportedAt: parseDate(map['reportedAt'] ?? map['ReportedAt']),
      status: status,
      workOrderId: (map['workOrderId'] ?? map['WorkOrderId'])?.toString(),
      resolvedByUserId:
          (map['resolvedByUserId'] ?? map['ResolvedByUserId'])?.toString(),
      resolvedByUserName:
          (map['resolvedByUserName'] ?? map['ResolvedByUserName'])?.toString(),
      resolvedAt: parseDate(map['resolvedAt'] ?? map['ResolvedAt']),
      rejectionReason:
          (map['rejectionReason'] ?? map['RejectionReason'])?.toString(),
      rejectedByUserId:
          (map['rejectedByUserId'] ?? map['RejectedByUserId'])?.toString(),
      rejectedByUserName:
          (map['rejectedByUserName'] ?? map['RejectedByUserName'])?.toString(),
      rejectedAt: parseDate(map['rejectedAt'] ?? map['RejectedAt']),
    );
  }

  factory BreakdownReportModel.fromFirestore(
    Map<String, dynamic> map,
    String docId,
  ) {
    return BreakdownReportModel.fromJson(map, docId);
  }

  Map<String, dynamic> toJson() {
    return {
      'assetCode': assetId,
      'assetName': assetName,
      'areaId': areaId,
      'description': description,
      'severity': severity.name,
      'status': status.name,
      if (workOrderId != null) 'workOrderId': workOrderId,
      if (rejectionReason != null) 'reason': rejectionReason,
    };
  }
}
