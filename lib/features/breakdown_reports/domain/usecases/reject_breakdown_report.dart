import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/breakdown_report_repository.dart';

class RejectBreakdownReportParams {
  const RejectBreakdownReportParams({
    required this.reportId,
    required this.reason,
    required this.rejectedByUserId,
    required this.rejectedByUserName,
  });

  final String reportId;
  final String reason;
  final String rejectedByUserId;
  final String rejectedByUserName;
}

class RejectBreakdownReportUseCase
    implements UseCase<void, RejectBreakdownReportParams> {
  const RejectBreakdownReportUseCase(this._repository);

  final BreakdownReportRepository _repository;

  @override
  Future<void> call(RejectBreakdownReportParams params) {
    if (params.reason.trim().isEmpty) {
      throw const ValidationFailure(message: 'Indica el motivo del rechazo.');
    }
    return _repository.rejectReport(
      reportId: params.reportId,
      reason: params.reason,
      rejectedByUserId: params.rejectedByUserId,
      rejectedByUserName: params.rejectedByUserName,
    );
  }
}
