import 'package:flutter/foundation.dart';

import '../../data/dashboard_repository.dart';
import '../../domain/entities/dashboard_stats.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({required DashboardRepository dashboardRepository})
      : _dashboardRepository = dashboardRepository;

  final DashboardRepository _dashboardRepository;

  DashboardStats? _stats;
  DashboardStats? get stats => _stats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Future<void> loadStats() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _stats = await _dashboardRepository.getStats();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
