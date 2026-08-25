import '../../../../core/usecases/usecase.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class LoginParams {
  const LoginParams({required this.username, required this.password});

  final String username;
  final String password;
}

class LoginUseCase implements UseCase<AppUser?, LoginParams> {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<AppUser?> call(LoginParams params) {
    return _repository.login(
      username: params.username.trim(),
      password: params.password,
    );
  }
}
