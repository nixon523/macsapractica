import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

class GetEmployeesParams {
  const GetEmployeesParams({
    this.onlyActive = true,
    this.isMaintenance,
    this.areaId,
    this.searchQuery,
  });

  final bool onlyActive;
  final bool? isMaintenance;
  final String? areaId;
  final String? searchQuery;
}

class GetEmployeesUseCase {
  const GetEmployeesUseCase(this._repository);

  final EmployeeRepository _repository;

  Future<List<Employee>> call([GetEmployeesParams params = const GetEmployeesParams()]) {
    return _repository.getEmployees(
      onlyActive: params.onlyActive,
      isMaintenance: params.isMaintenance,
      areaId: params.areaId,
      searchQuery: params.searchQuery,
    );
  }
}

