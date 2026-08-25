import '../domain/entities/dashboard_stats.dart';
import 'datasources/dashboard_remote_datasource.dart';

class DashboardRepository {
  const DashboardRepository(this._remoteDataSource);

  final DashboardRemoteDataSource _remoteDataSource;

  Future<DashboardStats> getStats() {
    return _remoteDataSource.getStats();
  }
}
