import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/kardex_log.dart';
import '../models/kardex_log_model.dart';

/// DataSource remoto de Kardex contra la API REST (SQL Server).
class KardexRemoteDataSource {
  const KardexRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<KardexLog>> getAllLogs({
    int limit = 50,
    String? module,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.kardexLogs,
      queryParameters: {
        'limit': limit,
        if (module != null && module.isNotEmpty) 'module': module,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      },
    );

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => KardexLogModel.fromJson(json))
          .toList();
    }
    return [];
  }

  Future<List<KardexLog>> getLogsForEntity(String entityId) async {
    final response =
        await _apiClient.get(ApiEndpoints.kardexByEntity(entityId));
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => KardexLogModel.fromJson(json))
          .toList();
    }
    return [];
  }

  Future<KardexLog> appendLog(KardexLog log) async {
    await _apiClient.post(
      ApiEndpoints.kardexLogs,
      body: {
        'action': log.action,
        'module': log.module,
        'entityId': log.entityId,
        'details': log.details,
      },
    );
    return log;
  }
}
