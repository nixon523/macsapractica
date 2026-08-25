import '../../../../core/usecases/usecase.dart';
import '../entities/app_user.dart';
import '../entities/user_role.dart';
import '../repositories/auth_repository.dart';

class CreateUserParams {
  const CreateUserParams({
    required this.username,
    required this.displayName,
    required this.password,
    required this.role,
  });

  final String username;
  final String displayName;
  final String password;
  final UserRole role;
}

class CreateUserUseCase implements UseCase<AppUser, CreateUserParams> {
  const CreateUserUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<AppUser> call(CreateUserParams params) {
    return _repository.createUser(
      username: params.username.trim(),
      displayName: params.displayName.trim(),
      password: params.password,
      role: params.role,
    );
  }
}
