import '../../../../core/usecases/usecase.dart';
import '../entities/breakdown_report.dart';
import '../repositories/breakdown_report_repository.dart';

class GetMyBreakdownReportsParams {
  const GetMyBreakdownReportsParams(this.userId);

  final String userId;
}

class GetMyBreakdownReportsUseCase
    implements UseCase<List<BreakdownReport>, GetMyBreakdownReportsParams> {
  const GetMyBreakdownReportsUseCase(this._repository);

  final BreakdownReportRepository _repository;

  @override
  Future<List<BreakdownReport>> call(GetMyBreakdownReportsParams params) {
    return _repository.getReportsByUser(params.userId);
  }
}
