import '../../../../core/usecases/usecase.dart';
import '../entities/breakdown_report.dart';
import '../repositories/breakdown_report_repository.dart';

class GetAllBreakdownReportsParams {
  const GetAllBreakdownReportsParams({
    this.status,
    this.startDate,
    this.endDate,
  });

  final BreakdownReportStatus? status;
  final DateTime? startDate;
  final DateTime? endDate;
}

class GetAllBreakdownReportsUseCase
    implements UseCase<List<BreakdownReport>, GetAllBreakdownReportsParams> {
  const GetAllBreakdownReportsUseCase(this._repository);

  final BreakdownReportRepository _repository;

  @override
  Future<List<BreakdownReport>> call([
    GetAllBreakdownReportsParams params = const GetAllBreakdownReportsParams(),
  ]) {
    return _repository.getAllReports(
      status: params.status,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}
