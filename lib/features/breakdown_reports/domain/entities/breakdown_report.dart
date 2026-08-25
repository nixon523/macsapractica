enum BreakdownReportStatus { reported, inWorkOrder, resolved, rejected }

enum BreakdownSeverity { low, medium, high }

class BreakdownReport {
  const BreakdownReport({
    required this.id,
    required this.assetId,
    required this.assetName,
    required this.areaId,
    required this.description,
    required this.severity,
    required this.reportedByUserId,
    required this.reportedByUserName,
    required this.reportedAt,
    required this.status,
    this.workOrderId,
    this.resolvedByUserId,
    this.resolvedByUserName,
    this.resolvedAt,
    this.rejectionReason,
    this.rejectedByUserId,
    this.rejectedByUserName,
    this.rejectedAt,
  });

  final String id;
  final String assetId;
  final String assetName;
  final String areaId;
  final String description;
  final BreakdownSeverity severity;
  final String reportedByUserId;
  final String reportedByUserName;
  final DateTime? reportedAt;
  final BreakdownReportStatus status;

  /// OT generada para atender este reporte (si existe).
  final String? workOrderId;

  final String? resolvedByUserId;
  final String? resolvedByUserName;
  final DateTime? resolvedAt;

  /// Justificación del rechazo (obligatoria al rechazar).
  final String? rejectionReason;

  final String? rejectedByUserId;
  final String? rejectedByUserName;
  final DateTime? rejectedAt;

  bool get isOpen =>
      status == BreakdownReportStatus.reported ||
      status == BreakdownReportStatus.inWorkOrder;

  String get severityLabel => switch (severity) {
        BreakdownSeverity.low => 'Baja',
        BreakdownSeverity.medium => 'Media',
        BreakdownSeverity.high => 'Alta',
      };

  String get statusLabel => switch (status) {
        BreakdownReportStatus.reported => 'Reportada',
        BreakdownReportStatus.inWorkOrder => 'En OT',
        BreakdownReportStatus.resolved => 'Resuelta',
        BreakdownReportStatus.rejected => 'Rechazada',
      };
}
