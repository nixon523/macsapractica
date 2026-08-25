import '../../../../core/usecases/usecase.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class GetAllUsersUseCase implements UseCase<List<AppUser>, NoParams> {
  const GetAllUsersUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<List<AppUser>> call(NoParams params) {
    return _repository.getAllUsers();
  }
}
