import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/universal_file_saver.dart';
import '../../../assets/domain/entities/area.dart';
import '../../../assets/domain/usecases/get_areas_usecase.dart';
import '../../../assets/presentation/reports/asset_report_preview_view.dart';
import '../../../assets/presentation/views/widgets/area_search_dialog.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/work_order.dart';
import '../../domain/usecases/get_all_work_orders.dart';
import 'work_order_excel_builder.dart';
import 'work_order_report_pdf_builder.dart';

/// Diálogo modal interactivo para personalizar y descargar reportes de Órdenes de Trabajo
/// (Filtros por Rango de Fecha, Área, Estado, Prioridad y Tipo de Orden en formatos PDF y Excel).
class WorkOrderReportFilterDialog extends StatefulWidget {
  const WorkOrderReportFilterDialog({
    super.key,
    this.initialOrders,
    this.initialAreaId,
    this.initialAreaName,
  });

  final List<WorkOrder>? initialOrders;
  final String? initialAreaId;
  final String? initialAreaName;

  static Future<void> show(
    BuildContext context, {
    List<WorkOrder>? initialOrders,
    String? initialAreaId,
    String? initialAreaName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => WorkOrderReportFilterDialog(
        initialOrders: initialOrders,
        initialAreaId: initialAreaId,
        initialAreaName: initialAreaName,
      ),
    );
  }

  @override
  State<WorkOrderReportFilterDialog> createState() => _WorkOrderReportFilterDialogState();
}

class _WorkOrderReportFilterDialogState extends State<WorkOrderReportFilterDialog> {
  List<Area> _areas = [];
  bool _isLoadingAreas = false;

  List<WorkOrder> _allLoadedOrders = [];
  bool _isLoadingOrders = false;

  // Filtros personalizables
  String _datePreset = 'mes';
  DateTime? _startDate;
  DateTime? _endDate;

  String? _selectedAreaId;
  String? _selectedAreaName;

  WorkOrderStatus? _selectedStatus;
  WorkOrderPriority? _selectedPriority;
  String _selectedWorkType = 'todos'; // todos, preventive, corrective, electric, mechanical, urgency
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _selectedAreaId = widget.initialAreaId;
    _selectedAreaName = widget.initialAreaName;

    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (widget.initialOrders != null && widget.initialOrders!.isNotEmpty) {
      _allLoadedOrders = List.from(widget.initialOrders!);
    }

    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadAreas();
    if (_allLoadedOrders.isEmpty) {
      await _fetchWorkOrders();
    }
  }

  Future<void> _loadAreas() async {
    setState(() => _isLoadingAreas = true);
    try {
      final getAreas = getIt<GetAreasUseCase>();
      final areas = await getAreas(const NoParams());
      if (mounted) {
        setState(() {
          _areas = areas;
          if (_selectedAreaId != null && _selectedAreaName == null) {
            final match = areas.where((a) => a.id == _selectedAreaId).firstOrNull;
            if (match != null) _selectedAreaName = match.name;
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingAreas = false);
  }

  Future<void> _fetchWorkOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final getAllOrders = getIt<GetAllWorkOrdersUseCase>();
      final orders = await getAllOrders(
        GetAllWorkOrdersParams(
          startDate: _startDate,
          endDate: _endDate,
        ),
      );
      if (mounted) {
        setState(() => _allLoadedOrders = orders);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar órdenes de trabajo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _datePreset = preset;
      switch (preset) {
        case 'hoy':
          _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'ayer':
          final yesterday = now.subtract(const Duration(days: 1));
          _startDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
          _endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
          break;
        case '7dias':
          final sevenDaysAgo = now.subtract(const Duration(days: 6));
          _startDate = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'mes':
          _startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'ano':
          _startDate = DateTime(now.year, 1, 1, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'todo':
          _startDate = null;
          _endDate = null;
          break;
      }
    });
    _fetchWorkOrders();
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );

    if (picked != null) {
      setState(() {
        _datePreset = 'personalizado';
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _fetchWorkOrders();
    }
  }

  Future<void> _selectArea() async {
    final areaId = await AreaSearchDialog.show(
      context,
      areas: _areas,
      currentAreaId: _selectedAreaId,
    );
    if (!mounted) return;

    setState(() {
      _selectedAreaId = areaId;
      if (areaId == null) {
        _selectedAreaName = null;
      } else {
        final found = _areas.where((a) => a.id == areaId).firstOrNull;
        _selectedAreaName = found?.name ?? areaId;
      }
    });
  }

  List<WorkOrder> get _filteredOrders {
    var list = _allLoadedOrders;

    // Filtro por Área
    if (_selectedAreaId != null && _selectedAreaId!.isNotEmpty) {
      list = list.where((o) => o.areaId == _selectedAreaId).toList();
    }

    // Filtro por Estado
    if (_selectedStatus != null) {
      list = list.where((o) => o.status == _selectedStatus).toList();
    }

    // Filtro por Prioridad
    if (_selectedPriority != null) {
      list = list.where((o) => o.priority == _selectedPriority).toList();
    }

    // Filtro por Tipo de Trabajo
    if (_selectedWorkType != 'todos') {
      if (_selectedWorkType == 'preventive') {
        list = list.where((o) => o.isPreventive).toList();
      } else if (_selectedWorkType == 'corrective') {
        list = list.where((o) => o.isCorrective).toList();
      } else {
        list = list.where((o) => o.requestedWorkTypes.contains(_selectedWorkType)).toList();
      }
    }

    // Filtro por Búsqueda rápida
    if (_searchQuery.isNotEmpty) {
      list = list.where((o) {
        final id = o.id.toLowerCase();
        final corr = (o.correlativeNumber ?? '').toLowerCase();
        final asset = o.assetName.toLowerCase();
        final code = o.assetId.toLowerCase();
        final desc = o.description.toLowerCase();
        final tech = (o.assignedTo ?? '').toLowerCase();
        return id.contains(_searchQuery) ||
            corr.contains(_searchQuery) ||
            asset.contains(_searchQuery) ||
            code.contains(_searchQuery) ||
            desc.contains(_searchQuery) ||
            tech.contains(_searchQuery);
      }).toList();
    }

    return list;
  }

  String get _dateRangeLabel {
    if (_startDate == null || _endDate == null) return 'Histórico completo';
    return '${_formatDate(_startDate!)} al ${_formatDate(_endDate!)}';
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _exportExcel() async {
    final filtered = _filteredOrders;
    if (filtered.isEmpty) {
      _showEmptyWarning();
      return;
    }

    setState(() => _isExporting = true);
    try {
      final areaMap = {for (final a in _areas) a.id: a.name};
      final bytes = await WorkOrderExcelBuilder.buildWorkOrdersExcel(
        workOrders: filtered,
        areaNamesMap: areaMap,
        dateFilterLabel: _dateRangeLabel,
      );

      final now = DateTime.now();
      final dateCode = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileName = 'Reporte_OrdenesTrabajo_Macsa_$dateCode.xlsx';

      await UniversalFileSaver.saveFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0055A5),
            content: Text('Reporte Excel generado con éxito ($fileName)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error al exportar Excel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _previewPdf() {
    final filtered = _filteredOrders;
    if (filtered.isEmpty) {
      _showEmptyWarning();
      return;
    }

    final authVm = context.read<AuthViewModel>();
    final userName = authVm.currentUser?.displayName ??
        authVm.currentUser?.username ??
        'Administración de Mantenimiento';
    final now = DateTime.now();
    final dateCode = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final fileName = 'Reporte_OrdenesTrabajo_Macsa_$dateCode.pdf';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetReportPreviewView(
          title: 'Reporte de Órdenes de Trabajo',
          fileName: fileName,
          initialIsPortrait: false, // Paisaje / Landscape para ver todas las columnas
          pdfBytesBuilder: (format) => WorkOrderReportPdfBuilder.buildPdf(
            workOrders: filtered,
            pageFormat: format,
            dateFilterLabel: _dateRangeLabel,
            areaFilterLabel: _selectedAreaName ?? 'Todas las Áreas',
            issuedByName: userName,
          ),
        ),
      ),
    );
  }

  void _showEmptyWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.orange,
        content: Text('No hay órdenes de trabajo que coincidan con los filtros seleccionados.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final matchingCount = _filteredOrders.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: circularBorderRadius(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera del diálogo
            _buildDialogHeader(isDark),

            // Contenido desplazable con filtros
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sección 1: Periodo / Fechas
                    _buildSectionTitle('1. Periodo y Rango de Fechas', Icons.date_range_rounded, isDark),
                    const SizedBox(height: 10),
                    _buildDatePresetsRow(isDark),
                    const SizedBox(height: 10),
                    _buildDateRangeDisplay(isDark),

                    const SizedBox(height: 20),

                    // Sección 2: Área y Filtros Operativos
                    _buildSectionTitle('2. Alcance Operativo (Área y Tipo)', Icons.tune_rounded, isDark),
                    const SizedBox(height: 10),
                    _buildAreaSelectorRow(isDark),
                    const SizedBox(height: 12),
                    _buildWorkTypeSelectorRow(isDark),

                    const SizedBox(height: 20),

                    // Sección 3: Estado y Prioridad
                    _buildSectionTitle('3. Estado y Prioridad', Icons.filter_alt_rounded, isDark),
                    const SizedBox(height: 10),
                    _buildStatusChips(isDark),
                    const SizedBox(height: 10),
                    _buildPriorityChips(isDark),

                    const SizedBox(height: 20),

                    // Sección 4: Búsqueda rápida
                    _buildSearchBox(isDark),
                  ],
                ),
              ),
            ),

            // Pie de página con contador y acciones de descarga
            _buildDialogFooter(isDark, matchingCount),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0055A5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assessment_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personalizar Reporte de Órdenes de Trabajo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Filtra por periodo, área, tipo, prioridad y descarga en PDF o Excel',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0055A5)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDatePresetsRow(bool isDark) {
    final presets = [
      ('hoy', 'Hoy'),
      ('ayer', 'Ayer'),
      ('7dias', '7 Días'),
      ('mes', 'Este Mes'),
      ('ano', 'Este Año'),
      ('todo', 'Histórico'),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: presets.map((p) {
        final isSelected = _datePreset == p.$1;
        return ChoiceChip(
          label: Text(p.$2),
          selected: isSelected,
          onSelected: (_) => _applyDatePreset(p.$1),
          selectedColor: const Color(0xFF0055A5),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateRangeDisplay(bool isDark) {
    return InkWell(
      onTap: _pickCustomDateRange,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _datePreset == 'personalizado' ? const Color(0xFF0055A5) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF0055A5)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rango Seleccionado: $_dateRangeLabel',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            const Text(
              'Personalizar',
              style: TextStyle(fontSize: 12, color: Color(0xFF0055A5), fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF0055A5)),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaSelectorRow(bool isDark) {
    return InkWell(
      onTap: _selectArea,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.apartment_rounded, size: 18, color: Color(0xFF0055A5)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Área Destino', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    _selectedAreaName ?? 'Todas las Áreas de Planta',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (_selectedAreaId != null)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                tooltip: 'Quitar filtro de área',
                onPressed: () => setState(() {
                  _selectedAreaId = null;
                  _selectedAreaName = null;
                }),
              )
            else
              const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkTypeSelectorRow(bool isDark) {
    final types = [
      ('todos', 'Todos los Tipos'),
      ('preventive', 'Preventivo'),
      ('corrective', 'Correctivo'),
      ('electric', 'Eléctrico'),
      ('mechanical', 'Mecánico'),
      ('urgency', 'Urgencia'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo / Clasificación de OT:', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: types.map((t) {
            final isSelected = _selectedWorkType == t.$1;
            return ChoiceChip(
              label: Text(t.$2),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedWorkType = t.$1),
              selectedColor: const Color(0xFF0055A5),
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusChips(bool isDark) {
    final statuses = [
      (null, 'Todos los Estados'),
      (WorkOrderStatus.pending, 'Pendiente'),
      (WorkOrderStatus.inProgress, 'En Progreso'),
      (WorkOrderStatus.completed, 'Completada'),
      (WorkOrderStatus.cancelled, 'Cancelada'),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: statuses.map((s) {
        final isSelected = _selectedStatus == s.$1;
        return ChoiceChip(
          label: Text(s.$2),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedStatus = s.$1),
          selectedColor: const Color(0xFF0055A5),
          labelStyle: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriorityChips(bool isDark) {
    final priorities = [
      (null, 'Todas las Prioridades'),
      (WorkOrderPriority.high, 'Alta'),
      (WorkOrderPriority.medium, 'Media'),
      (WorkOrderPriority.low, 'Baja'),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: priorities.map((p) {
        final isSelected = _selectedPriority == p.$1;
        return ChoiceChip(
          label: Text(p.$2),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedPriority = p.$1),
          selectedColor: const Color(0xFF0055A5),
          labelStyle: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchBox(bool isDark) {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        hintText: 'Filtrar por código de OT, activo o técnico...',
        hintStyle: const TextStyle(fontSize: 12),
        isDense: true,
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
      ),
    );
  }

  Widget _buildDialogFooter(bool isDark, int matchingCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final isNarrow = constraints.maxWidth < 580 || screenWidth < 620;

        final badge = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0055A5).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$matchingCount orden(es) a exportar',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0055A5),
                ),
              ),
            ),
            if (_isLoadingOrders) ...[
              const SizedBox(width: 8),
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        );

        final excelBtn = OutlinedButton.icon(
          onPressed: _isExporting ? null : _exportExcel,
          icon: const Icon(Icons.table_view_rounded, size: 18, color: Color(0xFF107C41)),
          label: const Text('Excel (.xlsx)', maxLines: 1, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white : Colors.black87,
            side: const BorderSide(color: Color(0xFF107C41)),
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 14, vertical: 10),
          ),
        );

        final pdfBtn = FilledButton.icon(
          onPressed: _isExporting ? null : _previewPdf,
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: const Text('Reporte PDF', maxLines: 1, overflow: TextOverflow.ellipsis),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0055A5),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 16, vertical: 10),
          ),
        );

        return Container(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 24, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: isNarrow
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    badge,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: excelBtn),
                        const SizedBox(width: 8),
                        Expanded(child: pdfBtn),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    badge,
                    Row(
                      children: [
                        excelBtn,
                        const SizedBox(width: 10),
                        pdfBtn,
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }

  BorderRadius circularBorderRadius(double r) => BorderRadius.circular(r);
}

