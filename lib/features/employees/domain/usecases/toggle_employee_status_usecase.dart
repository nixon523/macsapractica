import '../repositories/employee_repository.dart';

class ToggleEmployeeStatusUseCase {
  const ToggleEmployeeStatusUseCase(this._repository);

  final EmployeeRepository _repository;

  Future<void> call(int id, {required bool active}) {
    return _repository.toggleStatus(id: id, active: active);
  }
}

