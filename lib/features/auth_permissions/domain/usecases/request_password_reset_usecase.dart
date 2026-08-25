import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

class RequestPasswordResetParams {
  const RequestPasswordResetParams({
    required this.username,
    this.details,
  });

  final String username;
  final String? details;
}

class RequestPasswordResetUseCase
    implements UseCase<void, RequestPasswordResetParams> {
  const RequestPasswordResetUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<void> call(RequestPasswordResetParams params) {
    return _repository.requestPasswordReset(
      username: params.username.trim(),
      details: params.details,
    );
  }
}
