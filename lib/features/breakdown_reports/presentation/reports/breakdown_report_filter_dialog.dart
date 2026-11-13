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
import '../../domain/entities/breakdown_report.dart';
import '../../domain/usecases/get_all_breakdown_reports.dart';
import 'breakdown_report_excel_builder.dart';
import 'breakdown_report_pdf_builder.dart';

/// Diálogo modal interactivo para personalizar y descargar reportes de Averías e Incidencias
/// (Filtros por Fecha, Área, Severidad y Estado con exportación a PDF y Excel).
class BreakdownReportFilterDialog extends StatefulWidget {
  const BreakdownReportFilterDialog({
    super.key,
    this.initialReports,
    this.initialAreaId,
    this.initialAreaName,
  });

  final List<BreakdownReport>? initialReports;
  final String? initialAreaId;
  final String? initialAreaName;

  static Future<void> show(
    BuildContext context, {
    List<BreakdownReport>? initialReports,
    String? initialAreaId,
    String? initialAreaName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => BreakdownReportFilterDialog(
        initialReports: initialReports,
        initialAreaId: initialAreaId,
        initialAreaName: initialAreaName,
      ),
    );
  }

  @override
  State<BreakdownReportFilterDialog> createState() => _BreakdownReportFilterDialogState();
}

class _BreakdownReportFilterDialogState extends State<BreakdownReportFilterDialog> {
  List<Area> _areas = [];
  bool _isLoadingAreas = false;

  List<BreakdownReport> _allLoadedReports = [];
  bool _isLoadingReports = false;

  // Filtros
  String _datePreset = 'mes';
  DateTime? _startDate;
  DateTime? _endDate;

  String? _selectedAreaId;
  String? _selectedAreaName;

  BreakdownReportStatus? _selectedStatus;
  BreakdownSeverity? _selectedSeverity;
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

    if (widget.initialReports != null && widget.initialReports!.isNotEmpty) {
      _allLoadedReports = List.from(widget.initialReports!);
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
    if (_allLoadedReports.isEmpty) {
      await _fetchReports();
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

  Future<void> _fetchReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final getAllReports = getIt<GetAllBreakdownReportsUseCase>();
      final reports = await getAllReports(
        GetAllBreakdownReportsParams(
          startDate: _startDate,
          endDate: _endDate,
        ),
      );
      if (mounted) {
        setState(() => _allLoadedReports = reports);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar averías: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReports = false);
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
    _fetchReports();
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
      _fetchReports();
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

  List<BreakdownReport> get _filteredReports {
    var list = _allLoadedReports;

    // Filtro por Área
    if (_selectedAreaId != null && _selectedAreaId!.isNotEmpty) {
      list = list.where((r) => r.areaId == _selectedAreaId).toList();
    }

    // Filtro por Estado
    if (_selectedStatus != null) {
      list = list.where((r) => r.status == _selectedStatus).toList();
    }

    // Filtro por Severidad
    if (_selectedSeverity != null) {
      list = list.where((r) => r.severity == _selectedSeverity).toList();
    }

    // Búsqueda rápida
    if (_searchQuery.isNotEmpty) {
      list = list.where((r) {
        final id = r.id.toLowerCase();
        final code = r.assetId.toLowerCase();
        final name = r.assetName.toLowerCase();
        final desc = r.description.toLowerCase();
        final rep = r.reportedByUserName.toLowerCase();
        final ot = (r.workOrderId ?? '').toLowerCase();
        return id.contains(_searchQuery) ||
            code.contains(_searchQuery) ||
            name.contains(_searchQuery) ||
            desc.contains(_searchQuery) ||
            rep.contains(_searchQuery) ||
            ot.contains(_searchQuery);
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
    final filtered = _filteredReports;
    if (filtered.isEmpty) {
      _showEmptyWarning();
      return;
    }

    setState(() => _isExporting = true);
    try {
      final areaMap = {for (final a in _areas) a.id: a.name};
      final bytes = await BreakdownReportExcelBuilder.buildBreakdownExcel(
        reports: filtered,
        areaNamesMap: areaMap,
        dateFilterLabel: _dateRangeLabel,
      );

      final now = DateTime.now();
      final dateCode = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileName = 'Reporte_Averias_Macsa_$dateCode.xlsx';

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
    final filtered = _filteredReports;
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
    final fileName = 'Reporte_Averias_Macsa_$dateCode.pdf';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetReportPreviewView(
          title: 'Reporte de Averías e Incidencias',
          fileName: fileName,
          initialIsPortrait: false,
          pdfBytesBuilder: (format) => BreakdownReportPdfBuilder.buildPdf(
            reports: filtered,
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
        content: Text('No hay registros de averías que coincidan con los filtros.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final matchingCount = _filteredReports.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 700),
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

                    // Sección 2: Área
                    _buildSectionTitle('2. Filtrar por Área', Icons.apartment_rounded, isDark),
                    const SizedBox(height: 10),
                    _buildAreaSelectorRow(isDark),

                    const SizedBox(height: 20),

                    // Sección 3: Severidad y Estado
                    _buildSectionTitle('3. Severidad y Estado de la Incidencia', Icons.warning_amber_rounded, isDark),
                    const SizedBox(height: 10),
                    _buildSeverityChips(isDark),
                    const SizedBox(height: 10),
                    _buildStatusChips(isDark),

                    const SizedBox(height: 20),

                    // Sección 4: Búsqueda rápida
                    _buildSearchBox(isDark),
                  ],
                ),
              ),
            ),

            // Pie de página con acciones
            _buildDialogFooter(isDark, matchingCount),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: Color(0xFF0055A5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.build_circle_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personalizar Reporte de Averías e Incidencias',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Filtra por periodo, área, severidad y estado en formatos PDF o Excel',
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
                  const Text('Área', style: TextStyle(fontSize: 11, color: Colors.grey)),
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

  Widget _buildSeverityChips(bool isDark) {
    final severities = [
      (null, 'Todas las Severidades'),
      (BreakdownSeverity.high, 'Alta / Crítica'),
      (BreakdownSeverity.medium, 'Media'),
      (BreakdownSeverity.low, 'Baja'),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: severities.map((s) {
        final isSelected = _selectedSeverity == s.$1;
        return ChoiceChip(
          label: Text(s.$2),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedSeverity = s.$1),
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

  Widget _buildStatusChips(bool isDark) {
    final statuses = [
      (null, 'Todos los Estados'),
      (BreakdownReportStatus.reported, 'Reportada (Pendiente)'),
      (BreakdownReportStatus.inWorkOrder, 'En Orden de Trabajo'),
      (BreakdownReportStatus.resolved, 'Resuelta'),
      (BreakdownReportStatus.rejected, 'Rechazada'),
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

  Widget _buildSearchBox(bool isDark) {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        hintText: 'Buscar por código, activo, descripción o solicitante...',
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
                '$matchingCount avería(s) a exportar',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0055A5),
                ),
              ),
            ),
            if (_isLoadingReports) ...[
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
}

