import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/area.dart';
import '../models/area_model.dart';

/// DataSource remoto de Áreas contra la API REST (SQL Server).
class AreaRemoteDataSource {
  const AreaRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Area>> getAreas() async {
    final response = await _apiClient.get(ApiEndpoints.areas);
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => AreaModel.fromJson(json))
          .toList();
    }
    return [];
  }

  Future<Area> createArea({
    required String name,
    required String costCenter,
    String? customId,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.areas,
      body: {
        if (customId != null && customId.isNotEmpty) 'areaId': customId,
        'name': name,
        'costCenter': costCenter,
      },
    );

    String newId = customId ?? '';
    if (response is Map<String, dynamic>) {
      newId = (response['NewAreaId'] ?? response['newAreaId'] ?? response['areaId'] ?? newId).toString();
    }

    return AreaModel(
      id: newId.isNotEmpty ? newId : 'A001',
      name: name,
      costCenter: costCenter,
    );
  }

  Future<void> updateArea({
    required String id,
    required String name,
    String? costCenter,
  }) async {
    await _apiClient.put(
      ApiEndpoints.areaById(id),
      body: {
        'name': name,
        'costCenter': costCenter ?? '',
      },
    );
  }
}
