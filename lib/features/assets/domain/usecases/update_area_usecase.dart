import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/area_repository.dart';

class UpdateAreaParams {
  const UpdateAreaParams({
    required this.id,
    required this.name,
    this.costCenter,
  });

  final String id;
  final String name;
  final String? costCenter;
}

class UpdateAreaUseCase implements UseCase<void, UpdateAreaParams> {
  const UpdateAreaUseCase(this._repository);

  final AreaRepository _repository;

  @override
  Future<void> call(UpdateAreaParams params) {
    if (params.id.trim().isEmpty) {
      throw const ValidationFailure(message: 'El ID del área es obligatorio.');
    }

    if (params.name.trim().isEmpty) {
      throw const ValidationFailure(message: 'El nombre del área es obligatorio.');
    }

    return _repository.updateArea(
      id: params.id.trim(),
      name: params.name.trim(),
      costCenter: params.costCenter?.trim(),
    );
  }
}
