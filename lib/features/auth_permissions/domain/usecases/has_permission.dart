import '../../../../core/usecases/usecase.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class HasPermissionParams {
  const HasPermissionParams({
    required this.user,
    required this.permission,
  });

  final AppUser user;
  final String permission;
}

class HasPermissionUseCase implements UseCase<bool, HasPermissionParams> {
  const HasPermissionUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<bool> call(HasPermissionParams params) async {
    final user = await _repository.getUserById(params.user.userId);
    return user?.hasPermission(params.permission) ??
        params.user.hasPermission(params.permission);
  }
}
