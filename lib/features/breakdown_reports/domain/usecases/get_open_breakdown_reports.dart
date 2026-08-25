import '../../../../core/usecases/usecase.dart';
import '../entities/breakdown_report.dart';
import '../repositories/breakdown_report_repository.dart';

class GetOpenBreakdownReportsUseCase
    implements UseCase<List<BreakdownReport>, NoParams> {
  const GetOpenBreakdownReportsUseCase(this._repository);

  final BreakdownReportRepository _repository;

  @override
  Future<List<BreakdownReport>> call(NoParams params) {
    return _repository.getOpenReports();
  }
}
