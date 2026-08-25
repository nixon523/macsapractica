import 'package:flutter/foundation.dart';

import '../../domain/entities/kardex_log.dart';
import '../../domain/usecases/get_all_kardex_logs.dart';
import '../../domain/usecases/get_kardex_logs.dart';
import '../../../../core/usecases/usecase.dart';

class KardexListViewModel extends ChangeNotifier {
  KardexListViewModel({
    required GetAllKardexLogsUseCase getAllKardexLogsUseCase,
    required GetKardexLogsUseCase getKardexLogsUseCase,
  }) : _getAllKardexLogsUseCase = getAllKardexLogsUseCase,
       _getKardexLogsUseCase = getKardexLogsUseCase;

  final GetAllKardexLogsUseCase _getAllKardexLogsUseCase;
  final GetKardexLogsUseCase _getKardexLogsUseCase;

  List<KardexLog> _logs = [];
  List<KardexLog> get logs => _logs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Future<void> loadAll({
    int limit = 50,
    String? module,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _logs = await _getAllKardexLogsUseCase(
        GetAllKardexLogsParams(
          limit: limit,
          module: module,
          startDate: startDate,
          endDate: endDate,
        ),
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadForEntity(String entityId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _logs = await _getKardexLogsUseCase(GetKardexLogsParams(entityId));
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
