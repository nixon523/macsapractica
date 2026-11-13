import '../entities/employee.dart';
import '../entities/employee_position.dart';

abstract class EmployeeRepository {
  Future<List<Employee>> getEmployees({
    bool onlyActive = true,
    bool? isMaintenance,
    String? areaId,
    String? searchQuery,
  });

  Future<Employee> createEmployee({
    required String fullName,
    String? areaId,
    required String position,
    bool isMaintenance = true,
  });

  Future<Employee> updateEmployee({
    required int id,
    required String fullName,
    String? areaId,
    required String position,
    required bool isMaintenance,
    required bool isActive,
  });

  Future<void> toggleStatus({
    required int id,
    required bool active,
  });

  Future<List<EmployeePosition>> getPositions({bool onlyActive = true});

  Future<EmployeePosition> createPosition({
    required String name,
    required bool isMaintenance,
  });

  Future<EmployeePosition> updatePosition({
    required int id,
    required String name,
    required bool isMaintenance,
  });

  Future<void> deletePosition(int id);
}

