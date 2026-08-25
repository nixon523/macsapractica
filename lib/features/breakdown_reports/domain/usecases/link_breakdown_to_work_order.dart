import '../../../../core/usecases/usecase.dart';
import '../repositories/breakdown_report_repository.dart';

class LinkBreakdownToWorkOrderParams {
  const LinkBreakdownToWorkOrderParams({
    required this.reportId,
    required this.workOrderId,
    required this.userId,
    required this.userName,
  });

  final String reportId;
  final String workOrderId;
  final String userId;
  final String userName;
}

class LinkBreakdownToWorkOrderUseCase
    implements UseCase<void, LinkBreakdownToWorkOrderParams> {
  const LinkBreakdownToWorkOrderUseCase(this._repository);

  final BreakdownReportRepository _repository;

  @override
  Future<void> call(LinkBreakdownToWorkOrderParams params) {
    return _repository.linkWorkOrder(
      reportId: params.reportId,
      workOrderId: params.workOrderId,
      userId: params.userId,
      userName: params.userName,
    );
  }
}
