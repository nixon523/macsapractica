import '../../../../core/usecases/usecase.dart';
import '../entities/area.dart';
import '../repositories/area_repository.dart';

class GetAreasUseCase implements UseCase<List<Area>, NoParams> {
  const GetAreasUseCase(this._repository);

  final AreaRepository _repository;

  @override
  Future<List<Area>> call(NoParams params) {
    return _repository.getAreas();
  }
}
