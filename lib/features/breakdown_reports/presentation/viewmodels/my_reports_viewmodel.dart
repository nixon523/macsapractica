import 'package:flutter/foundation.dart';

import '../../domain/entities/breakdown_report.dart';
import '../../domain/usecases/get_my_breakdown_reports.dart';

enum MyReportsViewState { initial, loading, success, error }

/// ViewModel de "Mis Reportes": los reportes enviados por el usuario actual.
class MyReportsViewModel extends ChangeNotifier {
  MyReportsViewModel({required GetMyBreakdownReportsUseCase getMyReportsUseCase})
      : _getMyReportsUseCase = getMyReportsUseCase;

  final GetMyBreakdownReportsUseCase _getMyReportsUseCase;

  MyReportsViewState _viewState = MyReportsViewState.initial;
  MyReportsViewState get viewState => _viewState;

  List<BreakdownReport> _reports = const [];
  List<BreakdownReport> get reports => _reports;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Future<void> load(String userId) async {
    _viewState = MyReportsViewState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _reports = await _getMyReportsUseCase(GetMyBreakdownReportsParams(userId));
      _viewState = MyReportsViewState.success;
    } catch (e) {
      _errorMessage = e.toString();
      _viewState = MyReportsViewState.error;
    } finally {
      notifyListeners();
    }
  }
}
