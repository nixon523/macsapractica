import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/dashboard_stats.dart';

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
      );
    }

    return const DashboardStats(
      totalAssets: 0,
      pendingWorkOrders: 0,
      inProgressWorkOrders: 0,
      completedWorkOrders: 0,
      activeSchedules: 0,
      totalKardexLogs: 0,
    );
  }
}
