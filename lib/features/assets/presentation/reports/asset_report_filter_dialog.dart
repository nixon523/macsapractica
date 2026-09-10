import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../app/di/get_it.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/universal_file_saver.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/datasources/asset_remote_datasource.dart';
import '../../domain/entities/area.dart';
import '../../domain/entities/asset.dart';
import '../../domain/usecases/get_areas_usecase.dart';
import 'asset_area_inventory_pdf_builder.dart';
import 'asset_excel_builder.dart';
import 'asset_report_preview_view.dart';
import 'asset_single_pdf_builder.dart';

enum ReportScope { singleAsset, singleArea, multiArea }

/// Diálogo modal para configuración y generación de reportes (PDF / Excel)
class AssetReportFilterDialog extends StatefulWidget {
  const AssetReportFilterDialog({
    super.key,
    required this.scope,
    this.initialAsset,
    this.initialAreaId,
    this.initialAreaName,
  });

  final ReportScope scope;
  final Asset? initialAsset;
  final String? initialAreaId;
  final String? initialAreaName;

  static Future<void> showSingleAsset(BuildContext context, Asset asset, {String? areaName}) {
    return showDialog(
      context: context,
      builder: (_) => AssetReportFilterDialog(
        scope: ReportScope.singleAsset,
        initialAsset: asset,
        initialAreaId: asset.areaId,
        initialAreaName: areaName,
      ),
    );
  }

  static Future<void> showAreaReport(BuildContext context, {String? areaId, String? areaName}) {
    return showDialog(
      context: context,
      builder: (_) => AssetReportFilterDialog(
        scope: ReportScope.singleArea,
        initialAreaId: areaId,
        initialAreaName: areaName,
      ),
    );
  }

  static Future<void> showMultiAreaReport(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const AssetReportFilterDialog(
        scope: ReportScope.multiArea,
      ),
    );
  }

  @override
  State<AssetReportFilterDialog> createState() => _AssetReportFilterDialogState();
}

class _AssetReportFilterDialogState extends State<AssetReportFilterDialog> {
  List<Area> _areas = [];
  bool _loadingAreas = false;

  // Filtros
  late ReportScope _scope = widget.scope;
  String? _selectedAreaId;
  final Set<String> _selectedMultiAreaIds = {};
  bool _allAreasSelected = false;

  DateTime? _startDate;
  DateTime? _endDate;
  String _datePreset = 'todo';

  AssetStatus? _statusFilter;
  bool _onlyProcessEquipment = false;
  bool _includeSubComponents = true;

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _selectedAreaId = widget.initialAreaId;
    if (_selectedAreaId != null) {
      _selectedMultiAreaIds.add(_selectedAreaId!);
    }
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    setState(() => _loadingAreas = true);
    try {
      final list = await getIt<GetAreasUseCase>().call(const NoParams());
      if (mounted) {
        setState(() {
          _areas = list;
          _loadingAreas = false;
          if (_selectedAreaId == null && list.isNotEmpty && _scope == ReportScope.singleArea) {
            _selectedAreaId = list.first.id;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAreas = false);
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
        case 'semana':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          _startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'mes':
          _startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'anio':
          _startDate = DateTime(now.year, 1, 1, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'todo':
          _startDate = null;
          _endDate = null;
          break;
      }
    });
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
      helpText: 'Seleccionar Periodo de Reporte',
    );
    if (picked != null) {
      setState(() {
        _datePreset = 'personalizado';
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  Future<List<Asset>> _fetchAssetsForReport() async {
    final ds = AssetRemoteDataSource(getIt<ApiClient>());
    final List<String> targetAreaIds = [];

    if (_scope == ReportScope.singleAsset) {
      return [widget.initialAsset!];
    } else if (_scope == ReportScope.singleArea) {
      if (_selectedAreaId != null) targetAreaIds.add(_selectedAreaId!);
    } else {
      if (_allAreasSelected || _selectedMultiAreaIds.isEmpty) {
        targetAreaIds.addAll(_areas.map((a) => a.id));
      } else {
        targetAreaIds.addAll(_selectedMultiAreaIds);
      }
    }

    final List<Asset> result = [];
    for (final areaId in targetAreaIds) {
      List<Asset> areaAssets = [];
      if (_includeSubComponents) {
        areaAssets = await ds.getAllAssetsByArea(areaId);
      } else {
        areaAssets = await ds.getAssetsByArea(areaId);
      }
      result.addAll(areaAssets);
    }

    // Filtrar por estado
    var filtered = result;
    if (_statusFilter != null) {
      filtered = filtered.where((a) => a.status == _statusFilter).toList();
    }

    // Filtrar por equipo de proceso
    if (_onlyProcessEquipment) {
      filtered = filtered.where((a) => a.esEquipoProceso).toList();
    }

    // Filtrar por fecha de alta si se definió rango
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((a) {
        if (a.createdAt == null) return true;
        return a.createdAt!.isAfter(_startDate!) && a.createdAt!.isBefore(_endDate!);
      }).toList();
    }

    return filtered;
  }

  Map<String, String> _buildAreaNamesMap() {
    final map = <String, String>{};
    for (final a in _areas) {
      map[a.id] = a.name;
    }
    return map;
  }

  Future<void> _generatePdf() async {
    final authVm = getIt<AuthViewModel>();
    final userName = authVm.currentUser?.displayName ?? authVm.currentUser?.username ?? 'Usuario';
    final areaNames = _buildAreaNamesMap();

    if (_scope == ReportScope.singleAsset) {
      final asset = widget.initialAsset!;
      final areaName = widget.initialAreaName ?? areaNames[asset.areaId];

      List<Asset> subComponents = [];
      if (_includeSubComponents) {
        final ds = AssetRemoteDataSource(getIt<ApiClient>());
        subComponents = await ds.getAssetsByParent(parentAssetCode: asset.id);
      }

      final docTitle = 'Ficha Técnica - ${asset.id}';
      final fileName = 'ficha_tecnica_${asset.id}.pdf';

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AssetReportPreviewView(
            title: docTitle,
            fileName: fileName,
            pdfBytesBuilder: (format) => AssetSinglePdfBuilder.buildPdf(
              asset: asset,
              pageFormat: format,
              areaName: areaName,
              subComponents: subComponents,
              startDate: _startDate,
              endDate: _endDate,
              issuedByName: userName,
            ),
          ),
        ),
      );
    } else {
      setState(() => _isGenerating = true);
      try {
        final assets = await _fetchAssetsForReport();
        if (assets.isEmpty && mounted) {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontraron activos con los filtros seleccionados.')),
          );
          return;
        }

        final title = _scope == ReportScope.singleArea
            ? 'CATÁLOGO DE ACTIVOS - ${_selectedAreaId ?? ""}'
            : 'CONSOLIDADO DE ACTIVOS - PLANTA MACSA';
        final fileName = _scope == ReportScope.singleArea
            ? 'catalogo_activos_${_selectedAreaId ?? "area"}.pdf'
            : 'inventario_consolidado_activos.pdf';

        if (!mounted) return;
        Navigator.pop(context);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AssetReportPreviewView(
              title: title,
              fileName: fileName,
              pdfBytesBuilder: (format) => AssetAreaInventoryPdfBuilder.buildPdf(
                assets: assets,
                pageFormat: format,
                title: title,
                areaNamesMap: areaNames,
                issuedByName: userName,
              ),
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al preparar reporte: $e')),
          );
        }
      }
    }
  }

  Future<void> _generateExcel() async {
    setState(() => _isGenerating = true);
    try {
      final areaNames = _buildAreaNamesMap();
      final assets = await _fetchAssetsForReport();

      if (assets.isEmpty && mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontraron activos con los filtros seleccionados.')),
        );
        return;
      }

      final fileName = _scope == ReportScope.singleAsset
          ? 'ficha_${widget.initialAsset?.id ?? "activo"}.xlsx'
          : (_scope == ReportScope.singleArea
              ? 'inventario_${_selectedAreaId ?? "area"}.xlsx'
              : 'consolidado_activos_macsa.xlsx');

      final bytes = await AssetExcelBuilder.buildInventoryExcel(
        assets: assets,
        areaNamesMap: areaNames,
      );

      await UniversalFileSaver.saveFile(
        bytes: bytes,
        fileName: fileName,
      );

      if (mounted) {
        setState(() => _isGenerating = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archivo Excel descargado: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar Excel: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.description_outlined, color: colors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _scope == ReportScope.singleAsset
                                ? 'Generar Ficha Técnica / Reporte'
                                : (_scope == ReportScope.singleArea
                                    ? 'Reporte de Activos por Área'
                                    : 'Reporte Consolidado de Activos'),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _scope == ReportScope.singleAsset
                                ? 'Activo: ${widget.initialAsset?.id} - ${widget.initialAsset?.name}'
                                : 'Selecciona los parámetros para generar el documento.',
                            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Selector de Ámbito (si no es activo individual)
                if (_scope != ReportScope.singleAsset) ...[
                  Text('Alcance del Reporte', style: _sectionTitleStyle),
                  const SizedBox(height: 8),
                  SegmentedButton<ReportScope>(
                    segments: const [
                      ButtonSegment(
                        value: ReportScope.singleArea,
                        label: Text('Una Área'),
                        icon: Icon(Icons.location_on_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: ReportScope.multiArea,
                        label: Text('Multi-Área / Global'),
                        icon: Icon(Icons.corporate_fare, size: 16),
                      ),
                    ],
                    selected: {_scope},
                    onSelectionChanged: (val) {
                      setState(() => _scope = val.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Área individual
                  if (_scope == ReportScope.singleArea) ...[
                    Text('Seleccionar Área', style: _sectionTitleStyle),
                    const SizedBox(height: 6),
                    _loadingAreas
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<String>(
                            value: _selectedAreaId,
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: _areas
                                .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.id})')))
                                .toList(),
                            onChanged: (id) => setState(() => _selectedAreaId = id),
                          ),
                    const SizedBox(height: 16),
                  ],

                  // Multi-Áreas
                  if (_scope == ReportScope.multiArea) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Áreas a Incluir', style: _sectionTitleStyle),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _allAreasSelected = !_allAreasSelected;
                              if (_allAreasSelected) {
                                _selectedMultiAreaIds.addAll(_areas.map((a) => a.id));
                              } else {
                                _selectedMultiAreaIds.clear();
                              }
                            });
                          },
                          child: Text(_allAreasSelected ? 'Desmarcar todas' : 'Seleccionar todas'),
                        ),
                      ],
                    ),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _loadingAreas
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: _areas.length,
                              itemBuilder: (ctx, idx) {
                                final area = _areas[idx];
                                final isChecked = _selectedMultiAreaIds.contains(area.id);
                                return CheckboxListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  title: Text('${area.name} (${area.id})', style: const TextStyle(fontSize: 12)),
                                  value: isChecked,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedMultiAreaIds.add(area.id);
                                      } else {
                                        _selectedMultiAreaIds.remove(area.id);
                                        _allAreasSelected = false;
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],

                // Rango de fechas
                Text('Periodo / Rango de Fechas', style: _sectionTitleStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _presetChip('todo', 'Todo el historial'),
                    _presetChip('hoy', 'Hoy'),
                    _presetChip('semana', 'Esta semana'),
                    _presetChip('mes', 'Este mes'),
                    _presetChip('anio', 'Este año'),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: _pickCustomDateRange,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        _datePreset == 'personalizado' && _startDate != null && _endDate != null
                            ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                            : 'Personalizado',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filtros Adicionales (para catálogos)
                if (_scope != ReportScope.singleAsset) ...[
                  Text('Filtros de Inventario', style: _sectionTitleStyle),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<AssetStatus?>(
                          value: _statusFilter,
                          decoration: InputDecoration(
                            labelText: 'Estado Operativo',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Todos los estados', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: AssetStatus.active, child: Text('Solo Activos', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: AssetStatus.inactive, child: Text('Solo Inactivos', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: AssetStatus.transferredDeactivated, child: Text('Solo Transferidos', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) => setState(() => _statusFilter = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Switches de configuración
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir sub-equipos y partes (árbol jerárquico)', style: TextStyle(fontSize: 12.5)),
                  subtitle: Text(
                    _includeSubComponents ? 'Se listan todos los niveles de componentes' : 'Solo activos de nivel principal (equipos raíz)',
                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                  ),
                  value: _includeSubComponents,
                  onChanged: (v) => setState(() => _includeSubComponents = v),
                ),
                if (_scope != ReportScope.singleAsset)
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo Equipos de Proceso (Monitoreo Semanal)', style: TextStyle(fontSize: 12.5)),
                    subtitle: const Text('Filtra únicamente los equipos clasificados en línea de producción', style: TextStyle(fontSize: 11)),
                    value: _onlyProcessEquipment,
                    onChanged: (v) => setState(() => _onlyProcessEquipment = v),
                  ),

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Botones de Acción Dual (PDF vs Excel)
                if (_isGenerating)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  Row(
                    children: [
                      // Botón Excel
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade800,
                            side: BorderSide(color: Colors.green.shade600),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _generateExcel,
                          icon: const Icon(Icons.table_view_rounded, size: 18),
                          label: const Text('Exportar Excel (.xlsx)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Botón PDF
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _generatePdf,
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Ver / Imprimir PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presetChip(String key, String label) {
    final isSelected = _datePreset == key;
    final colors = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyDatePreset(key),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
      ),
      selectedColor: colors.primary,
      visualDensity: VisualDensity.compact,
    );
  }

  static const _sectionTitleStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.bold,
  );

  static String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
