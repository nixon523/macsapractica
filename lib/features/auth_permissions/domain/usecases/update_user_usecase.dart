import '../../../../core/usecases/usecase.dart';
import '../entities/user_role.dart';
import '../repositories/auth_repository.dart';

class UpdateUserParams {
  const UpdateUserParams({
    required this.userId,
    this.displayName,
    this.role,
    this.newPassword,
    this.permissions,
  });

  final String userId;
  final String? displayName;
  final UserRole? role;
  final String? newPassword;
  final Set<String>? permissions;
}

class UpdateUserUseCase implements UseCase<void, UpdateUserParams> {
  const UpdateUserUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<void> call(UpdateUserParams params) {
    return _repository.updateUser(
      userId: params.userId,
      displayName: params.displayName,
      role: params.role,
      newPassword: params.newPassword,
      permissions: params.permissions,
    );
  }
}

