import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_position.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_remote_datasource.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  EmployeeRepositoryImpl(this._remoteDataSource);

  final EmployeeRemoteDataSource _remoteDataSource;

  @override
  Future<List<Employee>> getEmployees({
    bool onlyActive = true,
    bool? isMaintenance,
    String? areaId,
    String? searchQuery,
  }) {
    return _remoteDataSource.getEmployees(
      onlyActive: onlyActive,
      isMaintenance: isMaintenance,
      areaId: areaId,
      searchQuery: searchQuery,
    );
  }

  @override
  Future<Employee> createEmployee({
    required String fullName,
    String? areaId,
    required String position,
    bool isMaintenance = true,
  }) {
    return _remoteDataSource.createEmployee(
      fullName: fullName,
      areaId: areaId,
      position: position,
      isMaintenance: isMaintenance,
    );
  }

  @override
  Future<Employee> updateEmployee({
    required int id,
    required String fullName,
    String? areaId,
    required String position,
    required bool isMaintenance,
    required bool isActive,
  }) {
    return _remoteDataSource.updateEmployee(
      id: id,
      fullName: fullName,
      areaId: areaId,
      position: position,
      isMaintenance: isMaintenance,
      isActive: isActive,
    );
  }

  @override
  Future<void> toggleStatus({
    required int id,
    required bool active,
  }) {
    return _remoteDataSource.toggleStatus(id: id, active: active);
  }

  @override
  Future<List<EmployeePosition>> getPositions({bool onlyActive = true}) {
    return _remoteDataSource.getPositions(onlyActive: onlyActive);
  }

  @override
  Future<EmployeePosition> createPosition({
    required String name,
    required bool isMaintenance,
  }) {
    return _remoteDataSource.createPosition(
      name: name,
      isMaintenance: isMaintenance,
    );
  }

  @override
  Future<EmployeePosition> updatePosition({
    required int id,
    required String name,
    required bool isMaintenance,
  }) {
    return _remoteDataSource.updatePosition(
      id: id,
      name: name,
      isMaintenance: isMaintenance,
    );
  }

  @override
  Future<void> deletePosition(int id) {
    return _remoteDataSource.deletePosition(id);
  }
}

