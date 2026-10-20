import 'package:flutter/foundation.dart';

import '../../../../app/di/get_it.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../assets/domain/entities/area.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/usecases/get_areas_usecase.dart';
import '../../../assets/domain/usecases/get_assets_by_area.dart';
import '../../../breakdown_reports/domain/entities/breakdown_report.dart';
import '../../../breakdown_reports/domain/usecases/link_breakdown_to_work_order.dart';
import '../../../breakdown_reports/presentation/viewmodels/breakdown_alerts_viewmodel.dart';
import '../../../breakdown_reports/presentation/viewmodels/my_reports_notifications_viewmodel.dart';
import '../../../preventive_schedules/domain/repositories/preventive_schedule_repository.dart';
import '../../domain/entities/work_order.dart';
import '../../domain/repositories/work_order_repository.dart';
import '../../domain/usecases/create_work_order.dart';
import 'work_order_alerts_viewmodel.dart';

/// Tipos de trabajo soportados en la plantilla oficial REG.GMC-MTN-001
const Map<String, String> kWorkTypeLabels = {
  'electric': 'Eléctrico',
  'mechanical': 'Mecánico',
  'welding': 'Soldadura',
  'refrigeration': 'Refrigeración',
  'plumbing': 'Plomería',
  'urgency': 'Urgencia',
  'preventive': 'Preventivo',
  'corrective': 'Correctivo',
  'scheduled': 'Programado',
};

class WorkOrderCreateViewModel extends ChangeNotifier {
  WorkOrderCreateViewModel({
    required CreateWorkOrderUseCase createWorkOrderUseCase,
    required LinkBreakdownToWorkOrderUseCase linkBreakdownToWorkOrderUseCase,
    GetAreasUseCase? getAreasUseCase,
    GetAssetsByAreaUseCase? getAssetsByAreaUseCase,
    WorkOrderRepository? workOrderRepository,
  })  : _createWorkOrderUseCase = createWorkOrderUseCase,
        _linkBreakdownToWorkOrderUseCase = linkBreakdownToWorkOrderUseCase,
        _getAreasUseCase = getAreasUseCase ??
            (getIt.isRegistered<GetAreasUseCase>() ? getIt<GetAreasUseCase>() : null),
        _getAssetsByAreaUseCase = getAssetsByAreaUseCase ??
            (getIt.isRegistered<GetAssetsByAreaUseCase>() ? getIt<GetAssetsByAreaUseCase>() : null),
        _workOrderRepository = workOrderRepository ??
            (getIt.isRegistered<WorkOrderRepository>() ? getIt<WorkOrderRepository>() : null);

  final CreateWorkOrderUseCase _createWorkOrderUseCase;
  final LinkBreakdownToWorkOrderUseCase _linkBreakdownToWorkOrderUseCase;
  final GetAreasUseCase? _getAreasUseCase;
  final GetAssetsByAreaUseCase? _getAssetsByAreaUseCase;
  final WorkOrderRepository? _workOrderRepository;

  List<Area> _areas = const [];
  List<Area> get areas => _areas;

  List<Asset> _assets = const [];
  List<Asset> get assets => _assets;

  bool _isLoadingAreas = false;
  bool get isLoadingAreas => _isLoadingAreas;

  bool _isLoadingAssets = false;
  bool get isLoadingAssets => _isLoadingAssets;

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

  List<WorkOrder> _openWorkOrders = const [];
  List<WorkOrder> get openWorkOrders => _openWorkOrders;

  WorkOrder? getOpenWorkOrderForAsset(String assetId) {
    final clean = assetId.trim();
    if (clean.isEmpty) return null;
    return _openWorkOrders.where((wo) {
      if (wo.assetId.trim() != clean) return false;
      return wo.status == WorkOrderStatus.pending || wo.status == WorkOrderStatus.inProgress;
    }).firstOrNull;
  }

  bool isAssetPending(String assetId) => getOpenWorkOrderForAsset(assetId) != null;

  Future<void> loadOpenWorkOrders() async {
    if (_workOrderRepository == null) return;
    try {
      final list = await _workOrderRepository.getOpenWorkOrders();
      _openWorkOrders = list.where((wo) =>
        wo.status == WorkOrderStatus.pending || wo.status == WorkOrderStatus.inProgress
      ).toList();
      notifyListeners();
    } catch (_) {
      try {
        final list = await _workOrderRepository.getAllWorkOrders();
        _openWorkOrders = list.where((wo) =>
          wo.status == WorkOrderStatus.pending || wo.status == WorkOrderStatus.inProgress
        ).toList();
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<void> loadAreas() async {
    if (_getAreasUseCase == null) {
      await loadOpenWorkOrders();
      return;
    }
    _isLoadingAreas = true;
    _errorMessage = '';
    notifyListeners();
    try {
      _areas = await _getAreasUseCase(const NoParams());
    } catch (_) {
    } finally {
      _isLoadingAreas = false;
      notifyListeners();
    }
    await loadOpenWorkOrders();
  }

  Future<void> selectArea(String areaId, {String? areaName}) async {
    _areaId = areaId;
    _areaName = areaName ?? _areas.where((a) => a.id == areaId).firstOrNull?.name ?? areaId;
    _assetId = '';
    _assetName = '';
    _assets = const [];
    _errorMessage = '';
    notifyListeners();

    if (_getAssetsByAreaUseCase != null) {
      _isLoadingAssets = true;
      notifyListeners();
      try {
        _assets = await _getAssetsByAreaUseCase(GetAssetsByAreaParams(areaId: areaId));
      } catch (_) {
      } finally {
        _isLoadingAssets = false;
        notifyListeners();
      }
    }
    await loadOpenWorkOrders();
  }

  void selectAsset(Asset asset) {
    _assetId = asset.id;
    _assetName = asset.name;
    if (asset.areaId.isNotEmpty && _areaId.isEmpty) {
      _areaId = asset.areaId;
    }
    if (isAssetPending(asset.id)) {
      final existing = getOpenWorkOrderForAsset(asset.id);
      _errorMessage =
          'El activo "${asset.name}" ya cuenta con la orden de trabajo ${existing?.id ?? ""} en estado pendiente/en progreso. No se puede crear una nueva orden.';
    } else {
      _errorMessage = '';
    }
    notifyListeners();
  }

  int? _assignedStaffCount;
  int? get assignedStaffCount => _assignedStaffCount;

  double? _estimatedHours;
  double? get estimatedHours => _estimatedHours;

  WorkOrderPriority _priority = WorkOrderPriority.medium;
  WorkOrderPriority get priority => _priority;

  final Set<String> _requestedWorkTypes = {'corrective'};
  Set<String> get requestedWorkTypes => Set.unmodifiable(_requestedWorkTypes);

  bool get isPreventive => _requestedWorkTypes.contains('preventive') || _preventiveSchedule != null;
  bool get isCorrective => !_requestedWorkTypes.contains('preventive') && (_requestedWorkTypes.contains('corrective') || _report != null || _preventiveSchedule == null);

  void setMaintenanceNature({required bool isPreventive}) {
    if (isPreventive) {
      _requestedWorkTypes.remove('corrective');
      _requestedWorkTypes.add('preventive');
    } else {
      _requestedWorkTypes.remove('preventive');
      _requestedWorkTypes.add('corrective');
    }
    notifyListeners();
  }

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
    loadOpenWorkOrders();
  }

  void initFromPreventiveSchedule(dynamic schedule) {
    _preventiveSchedule = schedule;
    _assetId = schedule.assetId;
    _assetName = schedule.assetName ?? '';
    _areaId = schedule.areaId;
    _areaName = schedule.areaName ?? '';
    _requestedWorkTypes.clear();
    _requestedWorkTypes.add('preventive');
    _requestedWorkTypes.add('scheduled');
    _materials.clear();

    final dynamic acts = schedule.activities;
    if (acts is List && acts.isNotEmpty) {
      final now = DateTime.now();
      // Actividades que vencen en el mes actual o todas las pendientes
      final monthActs = acts.where((a) {
        final next = a.nextDate as DateTime?;
        return next != null && next.year == now.year && next.month == now.month;
      }).toList();

      final targetActs = monthActs.isNotEmpty ? monthActs : acts;
      final buffer = StringBuffer();
      final equipName = schedule.assetName.isNotEmpty ? schedule.assetName : schedule.assetId;
      buffer.writeln('Mantenimiento Preventivo Programado (Plan ${schedule.id}) - $equipName');
      buffer.writeln('Actividades por componente:');

      for (final act in targetActs) {
        buffer.writeln('- ${act.childAssetName} (${act.childAssetId}): ${act.description}');
        for (final m in act.materials) {
          _materials.add(WorkOrderMaterial(
            description: '${m.name} (para ${act.childAssetName})',
            quantity: (m.quantity as num).toDouble(),
            unit: m.unit,
          ));
        }
      }
      _description = buffer.toString().trim();
    } else {
      final desc = schedule.description?.isNotEmpty == true
          ? schedule.description
          : schedule.maintenanceType;
      _description = 'Mantenimiento Preventivo Programado (Plan ${schedule.id}): $desc';
      if (schedule.materials != null) {
        for (final m in schedule.materials) {
          _materials.add(WorkOrderMaterial(
            description: m.name,
            quantity: (m.quantity as num).toDouble(),
            unit: m.unit,
          ));
        }
      }
    }

    if (schedule.estimatedHours != null) {
      _estimatedHours = (schedule.estimatedHours as num).toDouble();
    }
    notifyListeners();
    loadOpenWorkOrders();
  }

  void setAssetId(String value) {
    _assetId = value.trim();
    if (_assetId.isNotEmpty && isAssetPending(_assetId)) {
      final existing = getOpenWorkOrderForAsset(_assetId);
      _errorMessage =
          'El activo seleccionado ya cuenta con la orden de trabajo ${existing?.id ?? ""} en estado pendiente o en progreso. No se puede crear una orden duplicada.';
    } else {
      _errorMessage = '';
    }
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
    if (isAssetPending(_assetId)) {
      final existing = getOpenWorkOrderForAsset(_assetId);
      _errorMessage =
          'El activo seleccionado ya cuenta con la orden de trabajo ${existing?.id ?? ""} en estado pendiente o en progreso. Debe concluirse o cancelarse antes de emitir una nueva.';
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
          preventiveScheduleId: _preventiveSchedule != null ? _preventiveSchedule.id.toString() : null,
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

      // Refrescar inmediatamente los contadores de alertas y badges
      try {
        if (getIt.isRegistered<WorkOrderAlertsViewModel>()) {
          getIt<WorkOrderAlertsViewModel>().refresh();
        }
        if (_report != null) {
          if (getIt.isRegistered<BreakdownAlertsViewModel>()) {
            getIt<BreakdownAlertsViewModel>().refresh();
          }
          if (getIt.isRegistered<MyReportsNotificationsViewModel>()) {
            getIt<MyReportsNotificationsViewModel>().refresh();
          }
        }
      } catch (_) {}

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
