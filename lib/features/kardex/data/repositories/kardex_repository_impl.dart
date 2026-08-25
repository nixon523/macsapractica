import '../../domain/entities/kardex_log.dart';
import '../../domain/repositories/kardex_repository.dart';
import '../datasources/kardex_remote_datasource.dart';

class KardexRepositoryImpl implements KardexRepository {
  const KardexRepositoryImpl(this._remoteDataSource);

  final KardexRemoteDataSource _remoteDataSource;

  @override
  Future<List<KardexLog>> getAllLogs({
    int limit = 50,
    String? module,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _remoteDataSource.getAllLogs(
      limit: limit,
      module: module,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<List<KardexLog>> getLogsForEntity(String entityId) {
    return _remoteDataSource.getLogsForEntity(entityId);
  }

  @override
  Future<KardexLog> appendLog(KardexLog log) {
    return _remoteDataSource.appendLog(log);
  }
}
