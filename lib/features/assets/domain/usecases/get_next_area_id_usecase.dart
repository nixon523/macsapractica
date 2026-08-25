import '../../../../core/usecases/usecase.dart';
import '../repositories/area_repository.dart';

class GetNextAreaIdUseCase implements UseCase<String, NoParams> {
  const GetNextAreaIdUseCase(this._repository);

  final AreaRepository _repository;

  @override
  Future<String> call(NoParams params) {
    return _repository.getNextAreaId();
  }
}
