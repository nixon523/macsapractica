import 'package:flutter/foundation.dart';

import '../../../../app/di/get_it.dart';
import '../../../../core/error/failures.dart';
import '../../../breakdown_reports/domain/entities/breakdown_report.dart';
import '../../../breakdown_reports/domain/usecases/link_breakdown_to_work_order.dart';
import '../../../preventive_schedules/domain/repositories/preventive_schedule_repository.dart';
import '../../domain/entities/work_order.dart';
import '../../domain/usecases/create_work_order.dart';

/// Tipos de trabajo soportados en la plantilla oficial REG.GMC-MTN-001
const Map<String, String> kWorkTypeLabels = {
  'electric': 'Eléctrico',
  'mechanical': 'Mecánico',
  'urgency': 'Urgencia',
  'refrigeration': 'Refrigeración',
  'plumbing': 'Plomería',
  'preventive': 'Preventivo',
  'corrective': 'Correctivo',
  'scheduled': 'Programado',
};

class WorkOrderCreateViewModel extends ChangeNotifier {
  WorkOrderCreateViewModel({
    required CreateWorkOrderUseCase createWorkOrderUseCase,
    required LinkBreakdownToWorkOrderUseCase linkBreakdownToWorkOrderUseCase,
  })  : _createWorkOrderUseCase = createWorkOrderUseCase,
        _linkBreakdownToWorkOrderUseCase = linkBreakdownToWorkOrderUseCase;

  final CreateWorkOrderUseCase _createWorkOrderUseCase;
  final LinkBreakdownToWorkOrderUseCase _linkBreakdownToWorkOrderUseCase;

  BreakdownReport? _report;
  BreakdownReport? get report => _report;

  dynamic _preventiveSchedule;
  dynamic get preventiveSchedule => _preventiveSchedule;

  String _assetId = '';
  String get assetId => _assetId;

  String _assetName = '';
  String get assetName => _assetName;

  String _areaId = '';
  String get areaId => _areaId;

  String _areaName = '';
  String get areaName => _areaName;

  String _description = '';
  String get description => _description;

  String _assignedTo = '';
  String get assignedTo => _assignedTo;

  int? _assignedStaffCount;
  int? get assignedStaffCount => _assignedStaffCount;

  double? _estimatedHours;
  double? get estimatedHours => _estimatedHours;

  WorkOrderPriority _priority = WorkOrderPriority.medium;
  WorkOrderPriority get priority => _priority;

  final Set<String> _requestedWorkTypes = {'corrective'};
  Set<String> get requestedWorkTypes => Set.unmodifiable(_requestedWorkTypes);

  final List<WorkOrderMaterial> _materials = [];
  List<WorkOrderMaterial> get materials => List.unmodifiable(_materials);

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  void initFromReport(BreakdownReport? report) {
    _report = report;
    if (report != null) {
      _assetId = report.assetId;
      _assetName = report.assetName;
      _areaId = report.areaId;
      _description = report.description;
      _requestedWorkTypes.clear();
      _requestedWorkTypes.add('corrective');
      if (report.severity == BreakdownSeverity.high) {
        _priority = WorkOrderPriority.high;
      }
    }
    notifyListeners();
  }

  void initFromPreventiveSchedule(dynamic schedule) {
    _preventiveSchedule = schedule;
    _assetId = schedule.assetId;
    _assetName = schedule.assetName ?? '';
    _areaId = schedule.areaId;
    _areaName = schedule.areaName ?? '';
    final desc = schedule.description?.isNotEmpty == true
        ? schedule.description
        : schedule.maintenanceType;
    _description = '[Mantenimiento Preventivo ${schedule.id}]: $desc';
    _requestedWorkTypes.clear();
    _requestedWorkTypes.add('preventive');
    _requestedWorkTypes.add('scheduled');
    _materials.clear();
    if (schedule.materials != null) {
      for (final m in schedule.materials) {
        _materials.add(WorkOrderMaterial(
          description: m.name,
          quantity: (m.quantity as num).toDouble(),
          unit: m.unit,
        ));
      }
    }
    if (schedule.estimatedHours != null) {
      _estimatedHours = (schedule.estimatedHours as num).toDouble();
    }
    notifyListeners();
  }

  void setAssetId(String value) {
    _assetId = value.trim();
    notifyListeners();
  }

  void setAssetName(String value) {
    _assetName = value.trim();
    notifyListeners();
  }

  void setAreaId(String value) {
    _areaId = value.trim();
    notifyListeners();
  }

  void setAreaName(String value) {
    _areaName = value.trim();
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
    notifyListeners();
  }

  void setAssignedTo(String value) {
    _assignedTo = value.trim();
    notifyListeners();
  }

  void setAssignedStaffCount(int? value) {
    _assignedStaffCount = value;
    notifyListeners();
  }

  void setEstimatedHours(double? value) {
    _estimatedHours = value;
    notifyListeners();
  }

  void setPriority(WorkOrderPriority priority) {
    _priority = priority;
    notifyListeners();
  }

  void toggleWorkType(String typeKey) {
    if (_requestedWorkTypes.contains(typeKey)) {
      _requestedWorkTypes.remove(typeKey);
    } else {
      _requestedWorkTypes.add(typeKey);
    }
    notifyListeners();
  }

  void addMaterial(String description, double quantity, {String unit = 'pz'}) {
    final clean = description.trim();
    if (clean.isEmpty || quantity <= 0) return;
    _materials.add(WorkOrderMaterial(description: clean, quantity: quantity, unit: unit));
    notifyListeners();
  }

  void removeMaterial(int index) {
    if (index >= 0 && index < _materials.length) {
      _materials.removeAt(index);
      notifyListeners();
    }
  }

  Future<WorkOrder?> submit({
    required String userId,
    required String userName,
  }) async {
    _errorMessage = '';
    if (_preventiveSchedule != null && _preventiveSchedule.canGenerateWorkOrder == false) {
      _errorMessage = 'No se puede iniciar la Orden de Trabajo preventiva antes de su fecha/ventana de programación (máximo 7 días de anticipación).';
      notifyListeners();
      return null;
    }
    if (_assetId.isEmpty) {
      _errorMessage = 'Indica el ID del activo.';
      notifyListeners();
      return null;
    }
    if (_description.trim().isEmpty) {
      _errorMessage = 'Describe el trabajo a realizar.';
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    notifyListeners();
    try {
      final created = await _createWorkOrderUseCase(
        CreateWorkOrderParams(
          assetId: _assetId,
          assetName: _assetName.isEmpty ? _assetId : _assetName,
          areaId: _areaId.isEmpty ? null : _areaId,
          areaName: _areaName.isEmpty ? null : _areaName,
          description: _description.trim(),
          priority: _priority,
          requestedWorkTypes: _requestedWorkTypes.toList(),
          assignedTo: _assignedTo.isEmpty ? null : _assignedTo,
          assignedStaffCount: _assignedStaffCount,
          estimatedHours: _estimatedHours,
          materials: _materials,
          reportId: _report?.id,
          createdByUserId: userId,
          createdByUserName: userName,
        ),
      );

      if (_report != null) {
        await _linkBreakdownToWorkOrderUseCase(
          LinkBreakdownToWorkOrderParams(
            reportId: _report!.id,
            workOrderId: created.id,
            userId: userId,
            userName: userName,
          ),
        );
      }

      if (_preventiveSchedule != null) {
        try {
          await getIt<PreventiveScheduleRepository>().recordExecution(
            scheduleId: _preventiveSchedule.id,
            workOrderId: created.id,
            userId: userId,
            userName: userName,
          );
        } catch (_) {}
      }

      return created;
    } catch (e) {
      if (e is Failure) {
        _errorMessage = e.message;
      } else {
        final str = e.toString();
        _errorMessage = str.startsWith('Exception: ')
            ? str.substring(11)
            : str;
      }
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
