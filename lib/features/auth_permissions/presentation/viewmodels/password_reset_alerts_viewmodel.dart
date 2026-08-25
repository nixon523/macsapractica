import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/app_user.dart';

/// Alerta en tiempo real sobre solicitudes de restablecimiento de contraseña
/// pendientes (`passwordResetRequested == true`).
class PasswordResetAlertsViewModel extends ChangeNotifier {
  PasswordResetAlertsViewModel({
    AuthRemoteDataSource? remoteDataSource,
    Duration pollInterval = const Duration(seconds: 15),
  })  : _remoteDataSource = remoteDataSource,
        _pollInterval = pollInterval;

  final AuthRemoteDataSource? _remoteDataSource;
  final Duration _pollInterval;

  Timer? _timer;
  final Set<String> _knownUserIds = {};
  bool _initialized = false;
  int _pendingCount = 0;
  AppUser? _latestRequest;

  int get pendingCount => _pendingCount;
  AppUser? get latestRequest => _latestRequest;
  bool get isListening => _timer != null;

  void start() {
    if (_timer != null) return;
    final ds = _remoteDataSource;
    if (ds == null) return;

    _poll();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final users = await _remoteDataSource?.getAllUsers() ?? [];
      final pending = users.where((u) => u.passwordResetRequested).toList();
      processSnapshot(pending);
    } catch (error) {
      debugPrint('PasswordResetAlertsViewModel error: $error');
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _knownUserIds.clear();
    _initialized = false;
    _pendingCount = 0;
    _latestRequest = null;
    _notifySafely();
  }

  @visibleForTesting
  void processSnapshot(List<AppUser> users) {
    final isFirst = !_initialized;
    _initialized = true;

    final ids = {for (final user in users) user.userId};
    if (isFirst) {
      _knownUserIds
        ..clear()
        ..addAll(ids);
    } else {
      final newUsers =
          users.where((u) => !_knownUserIds.contains(u.userId)).toList();
      _knownUserIds.addAll(ids);
      if (_latestRequest == null && newUsers.isNotEmpty) {
        _latestRequest = newUsers.first;
      }
    }

    _pendingCount = users.length;
    _notifySafely();
  }

  void _notifySafely() {
    try {
      final binding = WidgetsBinding.instance;
      if (binding.schedulerPhase != SchedulerPhase.idle) {
        binding.addPostFrameCallback((_) {
          notifyListeners();
        });
        return;
      }
    } catch (_) {
      // Entorno de pruebas sin binding inicializado
    }
    notifyListeners();
  }

  AppUser? consumeLatestRequest() {
    final user = _latestRequest;
    _latestRequest = null;
    return user;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
