import 'package:flutter/foundation.dart';

import '../../../../app/di/get_it.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_position.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../domain/usecases/create_employee_usecase.dart';
import '../../domain/usecases/get_employees_usecase.dart';
import '../../domain/usecases/toggle_employee_status_usecase.dart';
import '../../domain/usecases/update_employee_usecase.dart';

enum EmployeeFilterCategory { all, maintenance, other }

class EmployeeListViewModel extends ChangeNotifier {
  EmployeeListViewModel({
    required GetEmployeesUseCase getEmployeesUseCase,
    required CreateEmployeeUseCase createEmployeeUseCase,
    required UpdateEmployeeUseCase updateEmployeeUseCase,
    required ToggleEmployeeStatusUseCase toggleEmployeeStatusUseCase,
    EmployeeRepository? employeeRepository,
  })  : _getEmployeesUseCase = getEmployeesUseCase,
        _createEmployeeUseCase = createEmployeeUseCase,
        _updateEmployeeUseCase = updateEmployeeUseCase,
        _toggleEmployeeStatusUseCase = toggleEmployeeStatusUseCase,
        _employeeRepository = employeeRepository ??
            (getIt.isRegistered<EmployeeRepository>()
                ? getIt<EmployeeRepository>()
                : null);

  final GetEmployeesUseCase _getEmployeesUseCase;
  final CreateEmployeeUseCase _createEmployeeUseCase;
  final UpdateEmployeeUseCase _updateEmployeeUseCase;
  final ToggleEmployeeStatusUseCase _toggleEmployeeStatusUseCase;
  final EmployeeRepository? _employeeRepository;

  List<Employee> _employees = [];
  List<Employee> get employees => _employees;

  List<EmployeePosition> _positions = [];
  List<EmployeePosition> get positions => _positions;

  bool _isLoadingPositions = false;
  bool get isLoadingPositions => _isLoadingPositions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  EmployeeFilterCategory _selectedCategory = EmployeeFilterCategory.all;
  EmployeeFilterCategory get selectedCategory => _selectedCategory;

  bool _showOnlyActive = true;
  bool get showOnlyActive => _showOnlyActive;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  List<Employee> get filteredEmployees {
    return _employees.where((e) {
      if (_showOnlyActive && !e.isActive) return false;
      if (_selectedCategory == EmployeeFilterCategory.maintenance && !e.isMaintenance) {
        return false;
      }
      if (_selectedCategory == EmployeeFilterCategory.other && e.isMaintenance) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = e.fullName.toLowerCase().contains(q);
        final matchesPos = e.position.toLowerCase().contains(q);
        final matchesArea = (e.areaName ?? '').toLowerCase().contains(q);
        if (!matchesName && !matchesPos && !matchesArea) return false;
      }
      return true;
    }).toList();
  }

  /// Lista rápida de técnicos de mantenimiento activos para selección en Órdenes de Trabajo.
  List<Employee> get maintenanceTechnicians {
    return _employees.where((e) => e.isActive && e.isMaintenance).toList();
  }

  void setCategory(EmployeeFilterCategory category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleShowOnlyActive() {
    _showOnlyActive = !_showOnlyActive;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  Future<void> loadEmployees() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _employees = await _getEmployeesUseCase(
        const GetEmployeesParams(onlyActive: false),
      );
      await loadPositions();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createEmployee({
    required String fullName,
    String? areaId,
    required String position,
    bool isMaintenance = true,
  }) async {
    _isSaving = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final newEmp = await _createEmployeeUseCase(
        CreateEmployeeParams(
          fullName: fullName,
          areaId: areaId,
          position: position,
          isMaintenance: isMaintenance,
        ),
      );
      _employees.insert(0, newEmp);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateEmployee({
    required int id,
    required String fullName,
    String? areaId,
    required String position,
    required bool isMaintenance,
    required bool isActive,
  }) async {
    _isSaving = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final updated = await _updateEmployeeUseCase(
        UpdateEmployeeParams(
          id: id,
          fullName: fullName,
          areaId: areaId,
          position: position,
          isMaintenance: isMaintenance,
          isActive: isActive,
        ),
      );
      final idx = _employees.indexWhere((e) => e.id == id);
      if (idx != -1) {
        _employees[idx] = updated;
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> toggleEmployeeStatus(int id, {required bool active}) async {
    try {
      await _toggleEmployeeStatusUseCase(id, active: active);
      final idx = _employees.indexWhere((e) => e.id == id);
      if (idx != -1) {
        _employees[idx] = _employees[idx].copyWith(isActive: active);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // Catálogo de Puestos / Cargos
  // --------------------------------------------------------------------------
  static const List<EmployeePosition> defaultPositionsFallback = [
    EmployeePosition(id: 1, name: 'Técnico Mecánico Industrial', isMaintenance: true),
    EmployeePosition(id: 2, name: 'Técnico Electricista / Automatización', isMaintenance: true),
    EmployeePosition(id: 3, name: 'Técnico Electromecánico', isMaintenance: true),
    EmployeePosition(id: 4, name: 'Técnico Soldador / Estructuras', isMaintenance: true),
    EmployeePosition(id: 5, name: 'Técnico en Refrigeración y Calderas', isMaintenance: true),
    EmployeePosition(id: 6, name: 'Jefe de Mantenimiento', isMaintenance: true),
    EmployeePosition(id: 7, name: 'Supervisor de Mantenimiento', isMaintenance: true),
    EmployeePosition(id: 8, name: 'Supervisor de Planta y Producción', isMaintenance: false),
    EmployeePosition(id: 9, name: 'Jefe de Aseguramiento de Calidad', isMaintenance: false),
  ];

  Future<void> loadPositions() async {
    if (_employeeRepository == null) {
      if (_positions.isEmpty) _positions = List.of(defaultPositionsFallback);
      return;
    }
    _isLoadingPositions = true;
    notifyListeners();
    try {
      final loaded = await _employeeRepository.getPositions(onlyActive: true);
      _positions = loaded.isNotEmpty ? loaded : List.of(defaultPositionsFallback);
    } catch (_) {
      if (_positions.isEmpty) {
        _positions = List.of(defaultPositionsFallback);
      }
    } finally {
      _isLoadingPositions = false;
      notifyListeners();
    }
  }

  Future<bool> createPosition({
    required String name,
    required bool isMaintenance,
  }) async {
    if (_employeeRepository == null) return false;
    _isSaving = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final created = await _employeeRepository.createPosition(
        name: name,
        isMaintenance: isMaintenance,
      );
      _positions.removeWhere((p) => p.id == created.id || p.name.toLowerCase() == created.name.toLowerCase());
      _positions.add(created);
      _positions.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updatePosition({
    required int id,
    required String name,
    required bool isMaintenance,
  }) async {
    if (_employeeRepository == null) return false;
    _isSaving = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final oldName = _positions.where((p) => p.id == id).firstOrNull?.name;
      final updated = await _employeeRepository.updatePosition(
        id: id,
        name: name,
        isMaintenance: isMaintenance,
      );
      final idx = _positions.indexWhere((p) => p.id == id);
      if (idx != -1) {
        _positions[idx] = updated;
      }
      _positions.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Refrescar lista de empleados en memoria si cambió el nombre del puesto
      if (oldName != null && oldName != updated.name) {
        _employees = _employees
            .map((e) => e.position == oldName ? e.copyWith(position: updated.name) : e)
            .toList();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deletePosition(int id) async {
    if (_employeeRepository == null) return false;
    _isSaving = true;
    _errorMessage = '';
    notifyListeners();
    try {
      await _employeeRepository.deletePosition(id);
      _positions.removeWhere((p) => p.id == id);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}

