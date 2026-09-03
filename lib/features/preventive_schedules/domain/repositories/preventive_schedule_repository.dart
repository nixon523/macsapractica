import '../entities/preventive_schedule.dart';

abstract class PreventiveScheduleRepository {
  Future<List<PreventiveSchedule>> getAllSchedules({
    String? areaId,
    ScheduleStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<PreventiveSchedule> createSchedule({
    required PreventiveSchedule schedule,
    required String userId,
    required String userName,
  });

  Future<void> amendSchedule({
    required String scheduleId,
    required String amendmentDocNumber,
    required String authorizedByManager,
    required String amendmentReason,
    required PreventiveSchedule updatedSchedule,
    required String userId,
    required String userName,
  });

  Future<void> recordExecution({
    required String scheduleId,
    required String workOrderId,
    required String userId,
    required String userName,
  });

  Future<void> toggleScheduleStatus({
    required String scheduleId,
    required ScheduleStatus status,
    required String amendmentDocNumber,
    required String authorizedByManager,
    required String reason,
    required String userId,
    required String userName,
  });

  Future<String> generateMonthlyWorkOrder({
    required String scheduleId,
    int? year,
    int? month,
  });
}
