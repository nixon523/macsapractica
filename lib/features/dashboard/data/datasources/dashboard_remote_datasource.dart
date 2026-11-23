import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/cost_center_maintenance_stats.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../models/cost_center_maintenance_stats_model.dart';

/// DataSource remoto de Dashboard contra la API REST (SQL Server).
class DashboardRemoteDataSource {
  const DashboardRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardStats> getStats() async {
    final response = await _apiClient.get(ApiEndpoints.dashboardStats);
    if (response is Map<String, dynamic>) {
      int parseNum(dynamic val) {
        if (val is int) return val;
        if (val is num) return val.toInt();
        return int.tryParse(val?.toString() ?? '') ?? 0;
      }

      double parseDouble(dynamic val) {
        if (val is double) return val;
        if (val is num) return val.toDouble();
        return double.tryParse(val?.toString() ?? '') ?? 100.0;
      }

      return DashboardStats(
        totalAssets: parseNum(response['TotalAssets'] ?? response['totalAssets']),
        pendingWorkOrders: parseNum(
            response['PendingWorkOrders'] ?? response['pendingWorkOrders']),
        inProgressWorkOrders: parseNum(
            response['InProgressWorkOrders'] ?? response['inProgressWorkOrders']),
        completedWorkOrders: parseNum(
            response['CompletedWorkOrders'] ?? response['completedWorkOrders']),
        activeSchedules: parseNum(response['ActivePreventiveSchedules'] ??
            response['activeSchedules']),
        totalKardexLogs:
            parseNum(response['TotalKardexLogs'] ?? response['totalKardexLogs']),
        openBreakdowns: parseNum(
            response['OpenBreakdowns'] ?? response['openBreakdowns']),
        urgentSchedules: parseNum(
            response['UrgentPreventiveSchedules'] ?? response['urgentSchedules']),
        overdueSchedules: parseNum(
            response['OverduePreventiveSchedules'] ?? response['overdueSchedules']),
        pmComplianceRate: parseDouble(
            response['PmComplianceRate'] ?? response['pmComplianceRate']),
      );
    }

    return const DashboardStats(
      totalAssets: 0,
      pendingWorkOrders: 0,
      inProgressWorkOrders: 0,
      completedWorkOrders: 0,
      activeSchedules: 0,
      totalKardexLogs: 0,
      openBreakdowns: 0,
      urgentSchedules: 0,
      overdueSchedules: 0,
      pmComplianceRate: 100.0,
    );
  }

  Future<List<CostCenterMaintenanceStats>> getMaintenanceByCostCenter({
    DateTime? startDate,
    DateTime? endDate,
    bool onlyWithMaintenance = false,
  }) async {
    final params = <String, String>{};
    if (startDate != null) params['startDate'] = startDate.toIso8601String();
    if (endDate != null) params['endDate'] = endDate.toIso8601String();
    if (onlyWithMaintenance) params['onlyWithMaintenance'] = 'true';

    final query = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
        : '';

    final response = await _apiClient.get('${ApiEndpoints.maintenanceByCostCenter}$query');
    if (response is List) {
      return response
          .map((item) => CostCenterMaintenanceStatsModel.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  Future<List<CostCenterMaintenanceDetail>> getMaintenanceByCostCenterDetails({
    String? costCenter,
    String? areaId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, String>{};
    if (costCenter != null && costCenter.isNotEmpty) params['costCenter'] = costCenter;
    if (areaId != null && areaId.isNotEmpty) params['areaId'] = areaId;
    if (startDate != null) params['startDate'] = startDate.toIso8601String();
    if (endDate != null) params['endDate'] = endDate.toIso8601String();

    final query = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
        : '';

    final response = await _apiClient.get('${ApiEndpoints.maintenanceByCostCenterDetails}$query');
    if (response is List) {
      return response
          .map((item) => CostCenterMaintenanceDetailModel.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }
}
