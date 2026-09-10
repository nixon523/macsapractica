import '../../../../core/usecases/usecase.dart';
import '../repositories/area_repository.dart';

class DeleteAreaUseCase implements UseCase<void, String> {
  const DeleteAreaUseCase(this.repository);

  final AreaRepository repository;

  @override
  Future<void> call(String areaId) async {
    return repository.deleteArea(areaId);
  }
}
