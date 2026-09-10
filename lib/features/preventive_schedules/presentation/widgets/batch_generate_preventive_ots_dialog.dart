import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/widgets/app_dialog.dart';
import '../../../assets/domain/entities/area.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/preventive_schedule.dart';
import '../viewmodels/preventive_schedule_viewmodel.dart';

class BatchGeneratePreventiveOtsDialog extends StatefulWidget {
  const BatchGeneratePreventiveOtsDialog({
    super.key,
    required this.schedules,
    required this.areas,
  });

  final List<PreventiveSchedule> schedules;
  final List<Area> areas;

  @override
  State<BatchGeneratePreventiveOtsDialog> createState() =>
      _BatchGeneratePreventiveOtsDialogState();
}

class _BatchGeneratePreventiveOtsDialogState
    extends State<BatchGeneratePreventiveOtsDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  Area? _selectedAreaFilter;
  bool _isGenerating = false;

  static const List<String> _monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  Future<void> _handleBatchGenerate(List<PreventiveSchedule> eligiblePlans) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    setState(() => _isGenerating = true);
    final vm = context.read<PreventiveScheduleViewModel>();

    try {
      int successCount = 0;
      final List<String> createdOts = [];

      for (final plan in eligiblePlans) {
        final otId = await vm.generateMonthlyWorkOrder(
          plan.id,
          year: _selectedYear,
          month: _selectedMonth,
        );
        if (otId != null && otId.isNotEmpty) {
          successCount++;
          createdOts.add(otId);
        }
      }

      if (!mounted) return;

      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡Se generaron $successCount Órdenes de Trabajo preventivas para ${_monthNames[_selectedMonth - 1]} de $_selectedYear exitosamente!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF047857),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              vm.errorMessage.isNotEmpty
                  ? vm.errorMessage
                  : 'No se pudieron generar las órdenes de trabajo.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = [currentYear - 1, currentYear, currentYear + 1, currentYear + 2];

    // Filtrar planes elegibles para el mes/año seleccionado
    final eligiblePlans = widget.schedules.where((schedule) {
      if (schedule.status != ScheduleStatus.active) return false;
      if (_selectedAreaFilter != null && schedule.areaId != _selectedAreaFilter!.id) {
        return false;
      }
      return schedule.hasActivitiesDueInPeriod(
        year: _selectedYear,
        month: _selectedMonth,
      );
    }).toList();

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_month,
                color: Color(0xFF0284C7), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Programar OTs Preventivas del Periodo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Generación consolidada de Órdenes de Trabajo por equipo según periodicidad',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: responsiveDialogWidth(context, 720),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Filtros de Periodo y Área
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event, size: 18, color: Color(0xFF475569)),
                        const SizedBox(width: 8),
                        const Text(
                          'Seleccionar Periodo:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int>(
                            value: _selectedMonth,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Mes',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: List.generate(12, (index) {
                              return DropdownMenuItem(
                                value: index + 1,
                                child: Text(_monthNames[index]),
                              );
                            }),
                            onChanged: (m) {
                              if (m != null) setState(() => _selectedMonth = m);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            value: _selectedYear,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Año',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: years.map((y) {
                              return DropdownMenuItem(value: y, child: Text('$y'));
                            }).toList(),
                            onChanged: (y) {
                              if (y != null) setState(() => _selectedYear = y);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (widget.areas.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<Area?>(
                        value: _selectedAreaFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Filtrar por Área (opcional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.apartment, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todas las Áreas'),
                          ),
                          ...widget.areas.map((a) {
                            return DropdownMenuItem(
                              value: a,
                              child: Text('${a.id} - ${a.name}'),
                            );
                          }),
                        ],
                        onChanged: (a) => setState(() => _selectedAreaFilter = a),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Lista de Equipos con Tareas Programadas para este Mes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Equipos que requieren mantenimiento en ${_monthNames[_selectedMonth - 1]} ($_selectedYear):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: eligiblePlans.isNotEmpty ? const Color(0xFFDCFCE7) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${eligiblePlans.length} equipo(s)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: eligiblePlans.isNotEmpty ? const Color(0xFF166534) : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (eligiblePlans.isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: eligiblePlans.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final plan = eligiblePlans[idx];
                      final acts = plan.activitiesDueInPeriod(
                        year: _selectedYear,
                        month: _selectedMonth,
                      );
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.precision_manufacturing, color: Color(0xFF0284C7)),
                        title: Text(
                          '${plan.assetId} - ${plan.assetName.isNotEmpty ? plan.assetName : plan.id}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Área: ${plan.areaName.isNotEmpty ? plan.areaName : plan.areaId} · Plan: ${plan.id}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            if (acts.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '• ${acts.length} tarea(s) en componentes: ${acts.map((a) => a.childAssetName).join(", ")}',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '1 OT a emitir',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Se creará 1 Orden de Trabajo preventiva consolidada para cada uno de los ${eligiblePlans.length} equipo(s). Las actividades con frecuencias mayores quedarán excluidas automáticamente.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 24, color: Colors.amber.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No hay planes preventivos con tareas pendientes para ${_monthNames[_selectedMonth - 1]} de $_selectedYear. Todos los equipos están al día para este período.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: (eligiblePlans.isNotEmpty && !_isGenerating)
              ? () => _handleBatchGenerate(eligiblePlans)
              : null,
          icon: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.playlist_add_check, size: 18),
          label: Text(
            _isGenerating
                ? 'Generando OTs...'
                : 'Generar ${eligiblePlans.length} Órdenes de Trabajo',
          ),
        ),
      ],
    );
  }
}
