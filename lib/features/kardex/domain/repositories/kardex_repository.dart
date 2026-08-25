import '../entities/kardex_log.dart';

abstract class KardexRepository {
  Future<List<KardexLog>> getAllLogs({
    int limit = 50,
    String? module,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<List<KardexLog>> getLogsForEntity(String entityId);
  Future<KardexLog> appendLog(KardexLog log);
}
