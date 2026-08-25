import '../../../../core/usecases/usecase.dart';
import '../entities/kardex_log.dart';
import '../repositories/kardex_repository.dart';

class GetKardexLogsParams {
  const GetKardexLogsParams(this.entityId);

  final String entityId;
}

class GetKardexLogsUseCase
    implements UseCase<List<KardexLog>, GetKardexLogsParams> {
  const GetKardexLogsUseCase(this._repository);

  final KardexRepository _repository;

  @override
  Future<List<KardexLog>> call(GetKardexLogsParams params) {
    return _repository.getLogsForEntity(params.entityId);
  }
}
