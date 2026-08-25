import '../entities/breakdown_report.dart';

abstract class BreakdownReportRepository {
  Future<BreakdownReport> createReport({
    required String assetId,
    required String assetName,
    required String areaId,
    required String description,
    required BreakdownSeverity severity,
    required String reportedByUserId,
    required String reportedByUserName,
  });

  Future<List<BreakdownReport>> getAllReports({
    BreakdownReportStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<BreakdownReport>> getReportsByUser(String userId);

  Future<List<BreakdownReport>> getOpenReports();

  /// Vincula un reporte con la OT creada para atenderlo.
  Future<void> linkWorkOrder({
    required String reportId,
    required String workOrderId,
    required String userId,
    required String userName,
  });

  /// Marca un reporte como resuelto (la avería ya fue atendida).
  Future<void> markResolved({
    required String reportId,
    required String resolvedByUserId,
    required String resolvedByUserName,
  });

  /// Rechaza un reporte sin generar OT. Exige una justificación.
  Future<void> rejectReport({
    required String reportId,
    required String reason,
    required String rejectedByUserId,
    required String rejectedByUserName,
  });
}
