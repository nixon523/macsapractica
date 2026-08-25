import '../../domain/entities/preventive_schedule.dart';
import '../../domain/repositories/preventive_schedule_repository.dart';
import '../datasources/preventive_schedule_remote_datasource.dart';

class PreventiveScheduleRepositoryImpl implements PreventiveScheduleRepository {
  const PreventiveScheduleRepositoryImpl(this._remoteDataSource);

  final PreventiveScheduleRemoteDataSource _remoteDataSource;

  @override
  Future<List<PreventiveSchedule>> getAllSchedules({
    String? areaId,
    ScheduleStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _remoteDataSource.getAllSchedules(
      areaId: areaId,
      status: status,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<PreventiveSchedule> createSchedule({
    required PreventiveSchedule schedule,
    required String userId,
    required String userName,
  }) {
    return _remoteDataSource.createSchedule(
      schedule: schedule,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<void> amendSchedule({
    required String scheduleId,
    required String amendmentDocNumber,
    required String authorizedByManager,
    required String amendmentReason,
    required PreventiveSchedule updatedSchedule,
    required String userId,
    required String userName,
  }) {
    return _remoteDataSource.amendSchedule(
      scheduleId: scheduleId,
      amendmentDocNumber: amendmentDocNumber,
      authorizedByManager: authorizedByManager,
      amendmentReason: amendmentReason,
      updatedSchedule: updatedSchedule,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<void> recordExecution({
    required String scheduleId,
    required String workOrderId,
    required String userId,
    required String userName,
  }) {
    return _remoteDataSource.recordExecution(
      scheduleId: scheduleId,
      workOrderId: workOrderId,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<void> toggleScheduleStatus({
    required String scheduleId,
    required ScheduleStatus status,
    required String amendmentDocNumber,
    required String authorizedByManager,
    required String reason,
    required String userId,
    required String userName,
  }) {
    return _remoteDataSource.toggleScheduleStatus(
      scheduleId: scheduleId,
      status: status,
      amendmentDocNumber: amendmentDocNumber,
      authorizedByManager: authorizedByManager,
      reason: reason,
      userId: userId,
      userName: userName,
    );
  }
}
