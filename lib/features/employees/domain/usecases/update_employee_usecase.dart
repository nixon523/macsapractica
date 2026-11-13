import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

class UpdateEmployeeParams {
  const UpdateEmployeeParams({
    required this.id,
    required this.fullName,
    this.areaId,
    required this.position,
    required this.isMaintenance,
    required this.isActive,
  });

  final int id;
  final String fullName;
  final String? areaId;
  final String position;
  final bool isMaintenance;
  final bool isActive;
}

class UpdateEmployeeUseCase {
  const UpdateEmployeeUseCase(this._repository);

  final EmployeeRepository _repository;

  Future<Employee> call(UpdateEmployeeParams params) {
    return _repository.updateEmployee(
      id: params.id,
      fullName: params.fullName,
      areaId: params.areaId,
      position: params.position,
      isMaintenance: params.isMaintenance,
      isActive: params.isActive,
    );
  }
}

