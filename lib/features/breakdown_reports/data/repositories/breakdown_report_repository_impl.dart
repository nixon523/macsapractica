import '../../domain/entities/breakdown_report.dart';
import '../../domain/repositories/breakdown_report_repository.dart';
import '../datasources/breakdown_report_remote_datasource.dart';

class BreakdownReportRepositoryImpl implements BreakdownReportRepository {
  const BreakdownReportRepositoryImpl({
    required this.remoteDataSource,
  });

  final BreakdownReportRemoteDataSource remoteDataSource;

  @override
  Future<BreakdownReport> createReport({
    required String assetId,
    required String assetName,
    required String areaId,
    required String description,
    required BreakdownSeverity severity,
    required String reportedByUserId,
    required String reportedByUserName,
  }) {
    return remoteDataSource.createReport(
      assetId: assetId,
      assetName: assetName,
      areaId: areaId,
      description: description,
      severity: severity,
      reportedByUserId: reportedByUserId,
      reportedByUserName: reportedByUserName,
    );
  }

  @override
  Future<List<BreakdownReport>> getAllReports({
    BreakdownReportStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return remoteDataSource.getAllReports(
      status: status,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<List<BreakdownReport>> getReportsByUser(String userId) {
    return remoteDataSource.getReportsByUser(userId);
  }

  @override
  Future<List<BreakdownReport>> getOpenReports() {
    return remoteDataSource.getOpenReports();
  }

  @override
  Future<void> linkWorkOrder({
    required String reportId,
    required String workOrderId,
    required String userId,
    required String userName,
  }) {
    return remoteDataSource.linkWorkOrder(
      reportId: reportId,
      workOrderId: workOrderId,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<void> markResolved({
    required String reportId,
    required String resolvedByUserId,
    required String resolvedByUserName,
  }) {
    return remoteDataSource.markResolved(
      reportId: reportId,
      resolvedByUserId: resolvedByUserId,
      resolvedByUserName: resolvedByUserName,
    );
  }

  @override
  Future<void> rejectReport({
    required String reportId,
    required String reason,
    required String rejectedByUserId,
    required String rejectedByUserName,
  }) {
    return remoteDataSource.rejectReport(
      reportId: reportId,
      reason: reason,
      rejectedByUserId: rejectedByUserId,
      rejectedByUserName: rejectedByUserName,
    );
  }
}
