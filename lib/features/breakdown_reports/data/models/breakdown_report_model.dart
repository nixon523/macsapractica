import '../../../../core/utils/text_sanitizer.dart';
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
        (map['reportId'] ??
                map['ReportId'] ??
                map['ReporteId'] ??
                map['reporteId'] ??
                map['id'] ??
                '')
            ?.toString() ??
        '';

    final severityStr =
        (map['severity'] ?? map['Severity'] ?? map['Severidad'] ?? 'medium')
            .toString();
    final severity = BreakdownSeverity.values.firstWhere(
      (e) => e.name.toLowerCase() == severityStr.toLowerCase(),
      orElse: () => BreakdownSeverity.medium,
    );

    final statusStr =
        (map['status'] ?? map['Status'] ?? map['Estado'] ?? 'reported')
            .toString();
    final status = BreakdownReportStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => BreakdownReportStatus.reported,
    );

    return BreakdownReportModel(
      id: id,
      assetId: (map['assetId'] ??
              map['AssetCode'] ??
              map['assetCode'] ??
              map['CodigoActivo'] ??
              '')
          .toString(),
      assetName: (map['assetName'] ??
              map['AssetName'] ??
              map['NombreActivo'] ??
              '')
          .toString(),
      areaId: (map['areaId'] ?? map['AreaId'] ?? '').toString(),
      description: TextSanitizer.cleanDescription((map['description'] ??
              map['Description'] ??
              map['Descripcion'] ??
              '')
          .toString()),
      severity: severity,
      reportedByUserId: (map['reportedByUserId'] ??
              map['ReportedByUserId'] ??
              map['ReportadoPorUsuarioId'] ??
              '')
          .toString(),
      reportedByUserName: (map['reportedByUserName'] ??
              map['ReportedByUserName'] ??
              map['ReportadoPorNombreUsuario'] ??
              '')
          .toString(),
      reportedAt: parseDate(map['reportedAt'] ??
          map['ReportedAt'] ??
          map['ReportadoEn']),
      status: status,
      workOrderId: (map['workOrderId'] ??
              map['WorkOrderId'] ??
              map['OrdenTrabajoId'])
          ?.toString(),
      resolvedByUserId: (map['resolvedByUserId'] ??
              map['ResolvedByUserId'] ??
              map['ResueltoPorUsuarioId'])
          ?.toString(),
      resolvedByUserName: (map['resolvedByUserName'] ??
              map['ResolvedByUserName'] ??
              map['ResueltoPorNombreUsuario'])
          ?.toString(),
      resolvedAt: parseDate(
          map['resolvedAt'] ?? map['ResolvedAt'] ?? map['ResueltoEn']),
      rejectionReason: (map['rejectionReason'] ??
              map['RejectionReason'] ??
              map['MotivoRechazo'])
          ?.toString(),
      rejectedByUserId: (map['rejectedByUserId'] ??
              map['RejectedByUserId'] ??
              map['RechazadoPorUsuarioId'])
          ?.toString(),
      rejectedByUserName: (map['rejectedByUserName'] ??
              map['RejectedByUserName'] ??
              map['RechazadoPorNombreUsuario'])
          ?.toString(),
      rejectedAt: parseDate(
          map['rejectedAt'] ?? map['RejectedAt'] ?? map['RechazadoEn']),
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
