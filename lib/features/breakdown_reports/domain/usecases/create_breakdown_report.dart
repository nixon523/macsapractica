import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/breakdown_report.dart';
import '../repositories/breakdown_report_repository.dart';

class CreateBreakdownReportParams {
  const CreateBreakdownReportParams({
    required this.assetId,
    required this.assetName,
    required this.areaId,
    required this.description,
    required this.severity,
    required this.reportedByUserId,
    required this.reportedByUserName,
  });

  final String assetId;
  final String assetName;
  final String areaId;
  final String description;
  final BreakdownSeverity severity;
  final String reportedByUserId;
  final String reportedByUserName;
}

class CreateBreakdownReportUseCase
    implements UseCase<BreakdownReport, CreateBreakdownReportParams> {
  const CreateBreakdownReportUseCase(this._repository);

  final BreakdownReportRepository _repository;

  @override
  Future<BreakdownReport> call(CreateBreakdownReportParams params) {
    if (params.description.trim().isEmpty) {
      throw const ValidationFailure(message: 'Describe la avería.');
    }
    if (params.assetId.trim().isEmpty) {
      throw const ValidationFailure(message: 'Selecciona el activo afectado.');
    }
    return _repository.createReport(
      assetId: params.assetId,
      assetName: params.assetName,
      areaId: params.areaId,
      description: params.description,
      severity: params.severity,
      reportedByUserId: params.reportedByUserId,
      reportedByUserName: params.reportedByUserName,
    );
  }
}
