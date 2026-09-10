import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/preventive_schedule.dart';
import '../models/preventive_schedule_model.dart';

/// DataSource remoto de Planes Preventivos contra la API REST (SQL Server).
class PreventiveScheduleRemoteDataSource {
  const PreventiveScheduleRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PreventiveSchedule>> getAllSchedules({
    String? areaId,
    ScheduleStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.preventiveSchedules,
      queryParameters: {
        if (areaId != null && areaId.isNotEmpty) 'area': areaId,
        if (status != null) 'status': status.name,
      },
    );

    if (response is List) {
      final list = response
          .whereType<Map<String, dynamic>>()
          .map((json) => PreventiveScheduleModel.fromJson(json))
          .toList();

      final filtered = list.where((s) {
        if (startDate != null && s.nextDate.isBefore(startDate)) {
          return false;
        }
        if (endDate != null && s.nextDate.isAfter(endDate)) {
          return false;
        }
        return true;
      }).toList();

      filtered.sort((a, b) => a.nextDate.compareTo(b.nextDate));
      return filtered;
    }
    return [];
  }

  Future<PreventiveSchedule> createSchedule({
    required PreventiveSchedule schedule,
    required String userId,
    required String userName,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.preventiveSchedules,
      body: {
        'title': schedule.title,
        'assetCode': schedule.assetId,
        'assetName': schedule.assetName,
        'areaId': schedule.areaId,
        'areaName': schedule.areaName,
        'maintenanceType': schedule.maintenanceType,
        'frequency': schedule.frequency.label,
        'description': schedule.description,
        'estimatedHours': schedule.estimatedHours,
        'startDate': schedule.startDate.toIso8601String(),
        'nextDate': schedule.nextDate.toIso8601String(),
        'lastCompleted': schedule.lastCompleted?.toIso8601String(),
        'lastWorkOrderId': schedule.lastWorkOrderId,
        'status': schedule.status.name,
        'notes': schedule.notes,
        'intervaloFrecuencia': schedule.frequencyInterval,
        'unidadFrecuencia': schedule.frequencyUnit,
        'actividades': schedule.activities.map((a) => a.toMap()).toList(),
        'activities': schedule.activities.map((a) => a.toMap()).toList(),
        'materials': schedule.materials
            .map((m) => {
                  'name': m.name,
                  'quantity': m.quantity,
                  'unit': m.unit,
                })
            .toList(),
      },
    );

    String newNumber = '';
    if (response is Map<String, dynamic>) {
      newNumber = (response['ScheduleId'] ??
              response['scheduleId'] ??
              response['id'] ??
              '')
          .toString();
    }

    return PreventiveScheduleModel(
      id: newNumber.isNotEmpty ? newNumber : 'PM-2026-0001',
      title: schedule.title.isNotEmpty
          ? schedule.title
          : 'Plan Preventivo $newNumber',
      assetId: schedule.assetId,
      assetName: schedule.assetName,
      areaId: schedule.areaId,
      areaName: schedule.areaName,
      maintenanceType: schedule.maintenanceType,
      frequency: schedule.frequency,
      description: schedule.description,
      materials: schedule.materials,
      estimatedHours: schedule.estimatedHours,
      startDate: schedule.startDate,
      nextDate: schedule.nextDate,
      lastCompleted: schedule.lastCompleted,
      lastWorkOrderId: schedule.lastWorkOrderId,
      status: schedule.status,
      notes: schedule.notes,
      createdByUserId: userId,
      createdByUserName: userName,
      createdAt: DateTime.now(),
    );
  }

  Future<void> amendSchedule({
    required String scheduleId,
    required String amendmentDocNumber,
    required String authorizedByManager,
    required String amendmentReason,
    required PreventiveSchedule updatedSchedule,
    required String userId,
    required String userName,
  }) async {
    await _apiClient.put(
      ApiEndpoints.amendPreventiveSchedule(scheduleId),
      body: {
        'title': updatedSchedule.title,
        'maintenanceType': updatedSchedule.maintenanceType,
        'frequency': updatedSchedule.frequency.label,
        'description': updatedSchedule.description,
        'estimatedHours': updatedSchedule.estimatedHours,
        'startDate': updatedSchedule.startDate.toIso8601String(),
        'nextDate': updatedSchedule.nextDate.toIso8601String(),
        'notes': updatedSchedule.notes,
        'amendmentDocNumber': amendmentDocNumber.trim(),
        'authorizedByManager': true,
        'amendmentReason': amendmentReason.trim(),
        'materials': updatedSchedule.materials
            .map((m) => {
                  'name': m.name,
                  'quantity': m.quantity,
                  'unit': m.unit,
                })
            .toList(),
      },
    );
  }

  Future<void> recordExecution({
    required String scheduleId,
    required String workOrderId,
    required String userId,
    required String userName,
  }) async {
    await _apiClient.post(
      ApiEndpoints.recordPreventiveExecution(scheduleId),
      body: {
        'workOrderId': workOrderId,
      },
    );
  }

  Future<void> toggleScheduleStatus({
    required String scheduleId,
    required ScheduleStatus status,
    required String amendmentDocNumber,
    required String authorizedByManager,
    required String reason,
    required String userId,
    required String userName,
  }) async {
    await _apiClient.patch(
      ApiEndpoints.togglePreventiveStatus(scheduleId),
      body: {
        'newStatus': status.name,
        'amendmentDocNumber': amendmentDocNumber.trim(),
        'authorizedByManager': true,
        'reason': reason.trim(),
      },
    );
  }

  Future<String> generateMonthlyWorkOrder(
    String scheduleId, {
    int? year,
    int? month,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.generateMonthlyWorkOrder(scheduleId),
      body: {
        if (year != null) 'anio': year,
        if (month != null) 'mes': month,
      },
    );
    if (response is Map<String, dynamic>) {
      return (response['workOrderId'] ?? response['NewWorkOrderId'] ?? '').toString();
    }
    return '';
  }

  Future<List<String>> generateBatchMonthlyWorkOrders({
    required int year,
    required int month,
    String? areaId,
    required String userId,
    required String userName,
  }) async {
    try {
      final response = await _apiClient.post(
        '/planes-preventivos/generar-ots-masivas',
        body: {
          'anio': year,
          'mes': month,
          if (areaId != null && areaId.isNotEmpty) 'areaId': areaId,
          'usuarioId': int.tryParse(userId),
          'nombreUsuario': userName,
        },
      );
      if (response is List) {
        return response
            .whereType<Map<String, dynamic>>()
            .where((r) => r['Exitoso'] == true || r['exitoso'] == true)
            .map((r) => (r['WorkOrderId'] ?? r['workOrderId'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
