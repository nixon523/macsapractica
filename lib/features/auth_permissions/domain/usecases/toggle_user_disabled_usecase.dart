import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

class ToggleUserDisabledParams {
  const ToggleUserDisabledParams({
    required this.userId,
    required this.disabled,
  });

  final String userId;
  final bool disabled;
}

class ToggleUserDisabledUseCase
    implements UseCase<void, ToggleUserDisabledParams> {
  const ToggleUserDisabledUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<void> call(ToggleUserDisabledParams params) {
    return _repository.toggleUserDisabled(
      userId: params.userId,
      disabled: params.disabled,
    );
  }
}
