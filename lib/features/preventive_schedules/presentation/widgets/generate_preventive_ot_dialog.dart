import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/widgets/app_dialog.dart';
import '../../domain/entities/preventive_schedule.dart';
import '../viewmodels/preventive_schedule_viewmodel.dart';

class GeneratePreventiveOtDialog extends StatefulWidget {
  const GeneratePreventiveOtDialog({
    super.key,
    required this.schedule,
  });

  final PreventiveSchedule schedule;

  @override
  State<GeneratePreventiveOtDialog> createState() =>
      _GeneratePreventiveOtDialogState();
}

class _GeneratePreventiveOtDialogState
    extends State<GeneratePreventiveOtDialog> {
  late int _selectedYear;
  late int _selectedMonth;
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
    // Si la próxima fecha del plan está en el futuro, sugerir ese mes
    if (widget.schedule.nextDate.isAfter(now)) {
      _selectedYear = widget.schedule.nextDate.year;
      _selectedMonth = widget.schedule.nextDate.month;
    } else {
      _selectedYear = now.year;
      _selectedMonth = now.month;
    }
  }

  Future<void> _handleGenerate() async {
    setState(() => _isGenerating = true);
    final vm = context.read<PreventiveScheduleViewModel>();

    try {
      final otId = await vm.generateMonthlyWorkOrder(
        widget.schedule.id,
        year: _selectedYear,
        month: _selectedMonth,
      );

      if (!mounted) return;

      if (otId != null && otId.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡Orden de Trabajo preventiva $otId generada con éxito!',
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
                  : 'No se pudo generar la OT preventiva.',
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
    final schedule = widget.schedule;

    final includedActs = schedule.activitiesDueInPeriod(
      year: _selectedYear,
      month: _selectedMonth,
    );

    final excludedActs = schedule.activitiesNotDueInPeriod(
      year: _selectedYear,
      month: _selectedMonth,
    );

    // Materiales de las actividades incluidas
    final includedMaterials = <PreventiveMaterial>[];
    for (final act in includedActs) {
      includedMaterials.addAll(act.materials);
    }
    // Si no hay sub-actividades pero el plan tiene materiales propios y vence en este mes
    if (schedule.activities.isEmpty &&
        schedule.nextDate.year == _selectedYear &&
        schedule.nextDate.month == _selectedMonth) {
      includedMaterials.addAll(schedule.materials);
    }

    final bool canGenerate = schedule.activities.isNotEmpty
        ? includedActs.isNotEmpty
        : (schedule.nextDate.year == _selectedYear &&
            schedule.nextDate.month == _selectedMonth);

    final currentYear = DateTime.now().year;
    final years = [currentYear - 1, currentYear, currentYear + 1, currentYear + 2];

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assignment_turned_in,
                color: Color(0xFF0284C7), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Generar Orden de Trabajo Preventiva',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Plan ${schedule.id} · ${schedule.assetName.isNotEmpty ? schedule.assetName : schedule.assetId}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: responsiveDialogWidth(context, 680),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selector de Periodo (Mes y Año)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 420;
                    final monthField = DropdownButtonFormField<int>(
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
                    );

                    final yearField = DropdownButtonFormField<int>(
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
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.event_note, size: 18, color: Color(0xFF475569)),
                              SizedBox(width: 8),
                              Text(
                                'Periodo Objetivo:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(flex: 3, child: monthField),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: yearField),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        const Icon(Icons.event_note, size: 20, color: Color(0xFF475569)),
                        const SizedBox(width: 10),
                        const Text(
                          'Periodo Objetivo:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: monthField),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: yearField),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Sección 1: Actividades que SÍ corresponden al periodo
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF0055A5), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Tareas a Realizar en este Periodo (${includedActs.isNotEmpty ? includedActs.length : (canGenerate ? 1 : 0)}):',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0055A5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (canGenerate) ...[
                if (includedActs.isNotEmpty) ...[
                  ...includedActs.map((act) {
                    final isOverdue = act.isOverdue;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0055A5).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF0055A5).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.task_alt, size: 16, color: Color(0xFF0055A5)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${act.childAssetName} (${act.childAssetId})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  act.description,
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isOverdue ? Colors.red.shade100 : const Color(0xFF0055A5).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Prog: ${act.nextDate.day.toString().padLeft(2, '0')}/${act.nextDate.month.toString().padLeft(2, '0')}/${act.nextDate.year}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isOverdue ? Colors.red.shade800 : const Color(0xFF0055A5),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Frecuencia: ${act.frequencyLabel}',
                                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF0055A5).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '• Mantenimiento General de Equipo: ${schedule.description.isNotEmpty ? schedule.description : schedule.maintenanceType}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.amber.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No hay actividades programadas para este equipo en ${_monthNames[_selectedMonth - 1]} de $_selectedYear. No es necesario generar OT para este mes.',
                          style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Sección 2: Actividades Excluidas (Frecuencias que no corresponden)
              if (excludedActs.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.do_not_disturb_on_outlined, color: Colors.grey.shade600, size: 17),
                    const SizedBox(width: 6),
                    Text(
                      'Tareas Excluidas para este Periodo (${excludedActs.length}):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Estas tareas tienen frecuencias mayores (trimestral, semestral, anual) y no corresponden a este mes:',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                ...excludedActs.map((act) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 15, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '[${act.childAssetId}] ${act.childAssetName}: ${act.description}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Toca: ${act.nextDate.day.toString().padLeft(2, '0')}/${act.nextDate.month.toString().padLeft(2, '0')}/${act.nextDate.year}',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // Sección 3: Materiales Consolidados
              if (includedMaterials.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Materiales y Repuestos Consolidados:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: includedMaterials.map((m) {
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.handyman, size: 14, color: Color(0xFF0284C7)),
                      label: Text(
                        '${m.quantity} ${m.unit} - ${m.name}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: const Color(0xFFF0F9FF),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock, size: 18, color: Color(0xFF475569)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'La Orden de Trabajo se creará en estado "Pendiente" y asignará automáticamente el tipo Preventivo Programado.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
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
          onPressed: (canGenerate && !_isGenerating) ? _handleGenerate : null,
          icon: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.bolt, size: 18),
          label: Text(_isGenerating ? 'Generando OT...' : 'Generar Orden de Trabajo (OT)'),
        ),
      ],
    );
  }
}
