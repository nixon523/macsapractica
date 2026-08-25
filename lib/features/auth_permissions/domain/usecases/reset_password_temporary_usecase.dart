import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

class ResetPasswordTemporaryParams {
  const ResetPasswordTemporaryParams({
    required this.userId,
    required this.temporaryPassword,
  });

  final String userId;
  final String temporaryPassword;
}

class ResetPasswordTemporaryUseCase
    implements UseCase<void, ResetPasswordTemporaryParams> {
  const ResetPasswordTemporaryUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<void> call(ResetPasswordTemporaryParams params) {
    return _repository.resetPasswordTemporary(
      userId: params.userId,
      temporaryPassword: params.temporaryPassword,
    );
  }
}
