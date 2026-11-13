import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

class CreateEmployeeParams {
  const CreateEmployeeParams({
    required this.fullName,
    this.areaId,
    required this.position,
    this.isMaintenance = true,
  });

  final String fullName;
  final String? areaId;
  final String position;
  final bool isMaintenance;
}

class CreateEmployeeUseCase {
  const CreateEmployeeUseCase(this._repository);

  final EmployeeRepository _repository;

  Future<Employee> call(CreateEmployeeParams params) {
    return _repository.createEmployee(
      fullName: params.fullName,
      areaId: params.areaId,
      position: params.position,
      isMaintenance: params.isMaintenance,
    );
  }
}

