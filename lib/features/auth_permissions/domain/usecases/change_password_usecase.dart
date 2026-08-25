import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

class ChangePasswordParams {
  const ChangePasswordParams({
    required this.userId,
    required this.newPassword,
  });

  final String userId;
  final String newPassword;
}

class ChangePasswordUseCase implements UseCase<void, ChangePasswordParams> {
  const ChangePasswordUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<void> call(ChangePasswordParams params) {
    return _repository.changePassword(
      userId: params.userId,
      newPassword: params.newPassword,
    );
  }
}
