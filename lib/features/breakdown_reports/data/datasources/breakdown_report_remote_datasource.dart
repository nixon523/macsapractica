import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/breakdown_report.dart';
import '../models/breakdown_report_model.dart';

/// DataSource remoto de Reportes de Avería contra la API REST (SQL Server).
class BreakdownReportRemoteDataSource {
  const BreakdownReportRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<BreakdownReport>> getAllReports({
    BreakdownReportStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.breakdownReports,
      queryParameters: {
        if (status != null) 'status': status.name,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      },
    );

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => BreakdownReportModel.fromJson(json))
          .toList();
    }
    return [];
  }

  Future<List<BreakdownReport>> getReportsByUser(String userId) async {
    final response = await _apiClient.get(ApiEndpoints.myBreakdownReports);
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => BreakdownReportModel.fromJson(json))
          .toList();
    }
    return [];
  }

  Future<List<BreakdownReport>> getOpenReports() async {
    final response = await _apiClient.get(ApiEndpoints.openBreakdownReports);
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => BreakdownReportModel.fromJson(json))
          .toList();
    }
    return [];
  }

  Future<BreakdownReport> createReport({
    required String assetId,
    required String assetName,
    required String areaId,
    required String description,
    required BreakdownSeverity severity,
    required String reportedByUserId,
    required String reportedByUserName,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.breakdownReports,
      body: {
        'assetCode': assetId,
        'assetName': assetName,
        'areaId': areaId,
        'description': description.trim(),
        'severity': severity.name,
      },
    );

    String newId = '';
    if (response is Map<String, dynamic>) {
      newId = (response['ReportId'] ??
              response['reportId'] ??
              response['id'] ??
              '')
          .toString();
    }

    return BreakdownReportModel(
      id: newId,
      assetId: assetId,
      assetName: assetName,
      areaId: areaId,
      description: description,
      severity: severity,
      reportedByUserId: reportedByUserId,
      reportedByUserName: reportedByUserName,
      reportedAt: DateTime.now(),
      status: BreakdownReportStatus.reported,
    );
  }

  Future<void> linkWorkOrder({
    required String reportId,
    required String workOrderId,
    required String userId,
    required String userName,
  }) async {
    await _apiClient.post(
      ApiEndpoints.linkBreakdownWorkOrder(reportId),
      body: {
        'workOrderId': int.tryParse(workOrderId) ?? workOrderId,
      },
    );
  }

  Future<void> markResolved({
    required String reportId,
    required String resolvedByUserId,
    required String resolvedByUserName,
  }) async {
    await _apiClient.post(
      ApiEndpoints.resolveBreakdownReport(reportId),
    );
  }

  Future<void> rejectReport({
    required String reportId,
    required String reason,
    required String rejectedByUserId,
    required String rejectedByUserName,
  }) async {
    await _apiClient.post(
      ApiEndpoints.rejectBreakdownReport(reportId),
      body: {
        'reason': reason.trim(),
      },
    );
  }
}
