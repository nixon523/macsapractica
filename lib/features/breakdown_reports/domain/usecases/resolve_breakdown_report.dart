import '../../../../core/usecases/usecase.dart';
import '../repositories/breakdown_report_repository.dart';

class ResolveBreakdownReportParams {
  const ResolveBreakdownReportParams({
    required this.reportId,
    required this.resolvedByUserId,
    required this.resolvedByUserName,
  });

  final String reportId;
  final String resolvedByUserId;
  final String resolvedByUserName;
}

class ResolveBreakdownReportUseCase
    implements UseCase<void, ResolveBreakdownReportParams> {
  const ResolveBreakdownReportUseCase(this._repository);

  final BreakdownReportRepository _repository;

  @override
  Future<void> call(ResolveBreakdownReportParams params) {
    return _repository.markResolved(
      reportId: params.reportId,
      resolvedByUserId: params.resolvedByUserId,
      resolvedByUserName: params.resolvedByUserName,
    );
  }
}
