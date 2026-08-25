import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/area.dart';
import '../repositories/area_repository.dart';

class CreateAreaParams {
  const CreateAreaParams({
    required this.name,
    required this.costCenter,
    this.customId,
  });

  final String name;
  final String costCenter;
  final String? customId;
}

class CreateAreaUseCase implements UseCase<Area, CreateAreaParams> {
  const CreateAreaUseCase(this._repository);

  final AreaRepository _repository;

  @override
  Future<Area> call(CreateAreaParams params) {
    if (params.name.trim().isEmpty) {
      throw const ValidationFailure(message: 'El nombre del área es obligatorio.');
    }

    if (params.costCenter.trim().isEmpty) {
      throw const ValidationFailure(message: 'El centro de costo es obligatorio.');
    }

    return _repository.createArea(
      name: params.name.trim(),
      costCenter: params.costCenter.trim(),
      customId: params.customId?.trim(),
    );
  }
}
