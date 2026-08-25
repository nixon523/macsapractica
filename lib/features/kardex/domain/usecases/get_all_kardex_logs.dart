import '../../../../core/usecases/usecase.dart';
import '../entities/kardex_log.dart';
import '../repositories/kardex_repository.dart';

class GetAllKardexLogsParams {
  const GetAllKardexLogsParams({
    this.limit = 50,
    this.module,
    this.startDate,
    this.endDate,
  });

  final int limit;
  final String? module;
  final DateTime? startDate;
  final DateTime? endDate;
}

class GetAllKardexLogsUseCase
    implements UseCase<List<KardexLog>, GetAllKardexLogsParams> {
  const GetAllKardexLogsUseCase(this._repository);

  final KardexRepository _repository;

  @override
  Future<List<KardexLog>> call([
    GetAllKardexLogsParams params = const GetAllKardexLogsParams(),
  ]) {
    return _repository.getAllLogs(
      limit: params.limit,
      module: params.module,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}
