import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/employee_model.dart';
import '../models/employee_position_model.dart';

class EmployeeRemoteDataSource {
  EmployeeRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<EmployeeModel>> getEmployees({
    bool onlyActive = true,
    bool? isMaintenance,
    String? areaId,
    String? searchQuery,
  }) async {
    final queryParams = <String, dynamic>{
      'onlyActive': onlyActive,
      if (isMaintenance != null) 'isMaintenance': isMaintenance,
      if (areaId != null && areaId.isNotEmpty) 'areaId': areaId,
      if (searchQuery != null && searchQuery.isNotEmpty) 'searchQuery': searchQuery,
    };

    final response = await _apiClient.get(
      ApiEndpoints.employees,
      queryParameters: queryParams,
    );

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((j) => EmployeeModel.fromJson(j))
          .toList();
    }
    return [];
  }

  Future<EmployeeModel> createEmployee({
    required String fullName,
    String? areaId,
    required String position,
    bool isMaintenance = true,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.employees,
      body: {
        'fullName': fullName.trim(),
        if (areaId != null && areaId.isNotEmpty) 'areaId': areaId,
        'position': position.trim(),
        'isMaintenance': isMaintenance,
      },
    );

    if (response is Map<String, dynamic>) {
      return EmployeeModel.fromJson(response);
    }
    return EmployeeModel(
      id: 0,
      fullName: fullName,
      areaId: areaId,
      position: position,
      isMaintenance: isMaintenance,
    );
  }

  Future<EmployeeModel> updateEmployee({
    required int id,
    required String fullName,
    String? areaId,
    required String position,
    required bool isMaintenance,
    required bool isActive,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.employeeById(id),
      body: {
        'fullName': fullName.trim(),
        if (areaId != null && areaId.isNotEmpty) 'areaId': areaId,
        'position': position.trim(),
        'isMaintenance': isMaintenance,
        'isActive': isActive,
      },
    );

    if (response is Map<String, dynamic>) {
      return EmployeeModel.fromJson(response);
    }
    return EmployeeModel(
      id: id,
      fullName: fullName,
      areaId: areaId,
      position: position,
      isMaintenance: isMaintenance,
      isActive: isActive,
    );
  }

  Future<void> toggleStatus({
    required int id,
    required bool active,
  }) async {
    await _apiClient.post(
      ApiEndpoints.toggleEmployeeStatus(id),
      body: {
        'active': active,
      },
    );
  }

  // --------------------------------------------------------------------------
  // Catálogo de Puestos / Cargos
  // --------------------------------------------------------------------------
  Future<List<EmployeePositionModel>> getPositions({bool onlyActive = true}) async {
    final response = await _apiClient.get(
      ApiEndpoints.employeePositions,
      queryParameters: {'onlyActive': onlyActive},
    );

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((j) => EmployeePositionModel.fromJson(j))
          .toList();
    }
    return [];
  }

  Future<EmployeePositionModel> createPosition({
    required String name,
    required bool isMaintenance,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.employeePositions,
      body: {
        'name': name.trim(),
        'isMaintenance': isMaintenance,
      },
    );

    if (response is Map<String, dynamic>) {
      return EmployeePositionModel.fromJson(response);
    }
    return EmployeePositionModel(
      id: 0,
      name: name.trim(),
      isMaintenance: isMaintenance,
    );
  }

  Future<EmployeePositionModel> updatePosition({
    required int id,
    required String name,
    required bool isMaintenance,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.employeePositionById(id),
      body: {
        'name': name.trim(),
        'isMaintenance': isMaintenance,
      },
    );

    if (response is Map<String, dynamic>) {
      return EmployeePositionModel.fromJson(response);
    }
    return EmployeePositionModel(
      id: id,
      name: name.trim(),
      isMaintenance: isMaintenance,
    );
  }

  Future<void> deletePosition(int id) async {
    await _apiClient.delete(ApiEndpoints.employeePositionById(id));
  }
}

