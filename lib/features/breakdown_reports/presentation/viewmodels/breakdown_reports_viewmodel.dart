import 'package:flutter/foundation.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/breakdown_report.dart';
import '../../domain/usecases/get_all_breakdown_reports.dart';
import '../../domain/usecases/reject_breakdown_report.dart';
import '../../domain/usecases/resolve_breakdown_report.dart';

enum BreakdownReportsViewState { initial, loading, success, error }

/// ViewModel de la bandeja de reportes de averías (gestor/lector): lista todos
/// los reportes y permite resolver o rechazar los que ya fueron atendidos.
class BreakdownReportsViewModel extends ChangeNotifier {
  BreakdownReportsViewModel({
    required GetAllBreakdownReportsUseCase getAllReportsUseCase,
    required ResolveBreakdownReportUseCase resolveReportUseCase,
    required RejectBreakdownReportUseCase rejectReportUseCase,
  })  : _getAllReportsUseCase = getAllReportsUseCase,
        _resolveReportUseCase = resolveReportUseCase,
        _rejectReportUseCase = rejectReportUseCase;

  final GetAllBreakdownReportsUseCase _getAllReportsUseCase;
  final ResolveBreakdownReportUseCase _resolveReportUseCase;
  final RejectBreakdownReportUseCase _rejectReportUseCase;

  BreakdownReportsViewState _viewState = BreakdownReportsViewState.initial;
  BreakdownReportsViewState get viewState => _viewState;

  List<BreakdownReport> _reports = const [];
  List<BreakdownReport> get reports => _reports;

  List<BreakdownReport> get openReports => _reports
      .where(
        (r) =>
            r.status == BreakdownReportStatus.reported ||
            r.status == BreakdownReportStatus.inWorkOrder,
      )
      .toList();

  List<BreakdownReport> get resolvedReports =>
      _reports.where((r) => r.status == BreakdownReportStatus.resolved).toList();

  List<BreakdownReport> get rejectedReports =>
      _reports.where((r) => r.status == BreakdownReportStatus.rejected).toList();

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  Future<void> load({
    BreakdownReportStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _viewState = BreakdownReportsViewState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _reports = await _getAllReportsUseCase(
        GetAllBreakdownReportsParams(
          status: status,
          startDate: startDate,
          endDate: endDate,
        ),
      );
      _viewState = BreakdownReportsViewState.success;
    } catch (e) {
      _errorMessage = e.toString();
      _viewState = BreakdownReportsViewState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> resolve({
    required BreakdownReport report,
    required String resolvedByUserId,
    required String resolvedByUserName,
  }) async {
    _isProcessing = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _resolveReportUseCase(
        ResolveBreakdownReportParams(
          reportId: report.id,
          resolvedByUserId: resolvedByUserId,
          resolvedByUserName: resolvedByUserName,
        ),
      );
      await load();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<bool> reject({
    required BreakdownReport report,
    required String reason,
    required String rejectedByUserId,
    required String rejectedByUserName,
  }) async {
    _isProcessing = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _rejectReportUseCase(
        RejectBreakdownReportParams(
          reportId: report.id,
          reason: reason,
          rejectedByUserId: rejectedByUserId,
          rejectedByUserName: rejectedByUserName,
        ),
      );
      await load();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
