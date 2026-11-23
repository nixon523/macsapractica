import '../domain/entities/cost_center_maintenance_stats.dart';
import '../domain/entities/dashboard_stats.dart';
import 'datasources/dashboard_remote_datasource.dart';

class DashboardRepository {
  const DashboardRepository(this._remoteDataSource);

  final DashboardRemoteDataSource _remoteDataSource;

  Future<DashboardStats> getStats() {
    return _remoteDataSource.getStats();
  }

  Future<List<CostCenterMaintenanceStats>> getMaintenanceByCostCenter({
    DateTime? startDate,
    DateTime? endDate,
    bool onlyWithMaintenance = false,
  }) {
    return _remoteDataSource.getMaintenanceByCostCenter(
      startDate: startDate,
      endDate: endDate,
      onlyWithMaintenance: onlyWithMaintenance,
    );
  }

  Future<List<CostCenterMaintenanceDetail>> getMaintenanceByCostCenterDetails({
    String? costCenter,
    String? areaId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _remoteDataSource.getMaintenanceByCostCenterDetails(
      costCenter: costCenter,
      areaId: areaId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
