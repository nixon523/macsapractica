import 'package:flutter/material.dart';

import '../../../../app/widgets/app_dialog.dart';
import '../../../work_orders/domain/entities/work_order.dart';
import '../../domain/entities/preventive_schedule.dart';

/// Diálogo modal detallado y formal para inspeccionar todo lo referente a un Plan de Mantenimiento Preventivo:
/// - Cabecera con Folio PM, Estado y Semáforo de Vencimiento
/// - Resumen del Equipo Principal y Área
/// - Desglose exhaustivo de componentes hijos con su próxima fecha individualizada, frecuencias e insumos
/// - Materiales y repuestos requeridos
/// - Historial de enmiendas gerenciales y acciones inmediatas (Generar OT, Editar, Pausar)
class PreventivePlanDetailDialog extends StatelessWidget {
  const PreventivePlanDetailDialog({
    super.key,
    required this.schedule,
    this.activeOt,
    this.canGenerateOt = false,
    this.isAdmin = false,
    this.onGenerateOt,
    this.onAmend,
    this.onToggleStatus,
  });

  final PreventiveSchedule schedule;
  final WorkOrder? activeOt;
  final bool canGenerateOt;
  final bool isAdmin;
  final VoidCallback? onGenerateOt;
  final VoidCallback? onAmend;
  final VoidCallback? onToggleStatus;

  static Future<void> show(
    BuildContext context, {
    required PreventiveSchedule schedule,
    WorkOrder? activeOt,
    bool canGenerateOt = false,
    bool isAdmin = false,
    VoidCallback? onGenerateOt,
    VoidCallback? onAmend,
    VoidCallback? onToggleStatus,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => PreventivePlanDetailDialog(
        schedule: schedule,
        activeOt: activeOt,
        canGenerateOt: canGenerateOt,
        isAdmin: isAdmin,
        onGenerateOt: onGenerateOt,
        onAmend: onAmend,
        onToggleStatus: onToggleStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (alertBg, alertTextColor, alertLabel) = switch (schedule.alertLevel) {
      PreventiveAlertLevel.overdue => (
          const Color(0xFFFEE2E2),
          const Color(0xFFDC2626),
          'Vencido hace ${schedule.daysRemaining.abs()} día(s)',
        ),
      PreventiveAlertLevel.urgent => (
          const Color(0xFFFFEDD5),
          const Color(0xFFC2410C),
          'Urgente: Vence en ${schedule.daysRemaining} día(s)',
        ),
      PreventiveAlertLevel.upcoming => (
          const Color(0xFFFEF3C7),
          const Color(0xFFB45309),
          'Próximo: Vence en ${schedule.daysRemaining} día(s)',
        ),
      PreventiveAlertLevel.onSchedule => (
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
          'Al día: Vence en ${schedule.daysRemaining} día(s)',
        ),
    };

    final isPaused = schedule.status == ScheduleStatus.paused;
    final nextDateStr = '${schedule.nextDate.day.toString().padLeft(2, "0")}/'
        '${schedule.nextDate.month.toString().padLeft(2, "0")}/'
        '${schedule.nextDate.year}';
    final startDateStr = '${schedule.startDate.day.toString().padLeft(2, "0")}/'
        '${schedule.startDate.month.toString().padLeft(2, "0")}/'
        '${schedule.startDate.year}';

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final sectionBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cardBg,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: responsiveDialogWidth(context, 780),
          maxHeight: 760,
        ),
        child: LayoutBuilder(
          builder: (context, dialogConstraints) {
            final isCompactDialog = dialogConstraints.maxWidth < 640 || isMobile;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera formal
                _buildHeader(context, isPaused, alertBg, alertTextColor, alertLabel, isCompactDialog),

                // Contenido deslizable
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isCompactDialog ? 14 : 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fila de 4 KPIs rápidos adaptados a móvil
                        _buildKpiRow(nextDateStr, isDark, borderColor, sectionBg, isCompactDialog),
                        const SizedBox(height: 18),

                        // Ficha del Activo y Equipo
                        _buildSectionHeader('1. Información del Activo y Equipo Principal', Icons.precision_manufacturing_rounded),
                        const SizedBox(height: 10),
                        _buildAssetInfoCard(startDateStr, nextDateStr, isDark, borderColor, sectionBg, textPrimary, textSecondary),
                        const SizedBox(height: 20),

                        // Desglose de Actividades por Componente
                        _buildSectionHeader(
                          '2. Desglose de Actividades por Componente (${schedule.activities.length})',
                          Icons.account_tree_rounded,
                        ),
                        const SizedBox(height: 10),
                        if (schedule.activities.isEmpty)
                          _buildEmptyActivitiesNotice(isDark, borderColor, sectionBg, textSecondary)
                        else
                          ...schedule.activities.map((act) => _buildActivityCard(act, isDark, borderColor, sectionBg, textPrimary, textSecondary)),
                        const SizedBox(height: 20),

                        // Materiales Globales
                        if (schedule.materials.isNotEmpty) ...[
                          _buildSectionHeader('3. Materiales e Insumos Globales del Plan', Icons.inventory_2_outlined),
                          const SizedBox(height: 10),
                          _buildMaterialsWrap(schedule.materials, isDark, borderColor, sectionBg),
                          const SizedBox(height: 20),
                        ],

                        // Auditoría y Enmiendas Gerenciales (si existen)
                        if (schedule.amendmentDocNumber != null && schedule.amendmentDocNumber!.isNotEmpty) ...[
                          _buildSectionHeader('4. Control de Enmiendas y Auditoría Gerencial', Icons.verified_user_outlined),
                          const SizedBox(height: 10),
                          _buildAmendmentCard(isDark, borderColor, textPrimary),
                        ],
                      ],
                    ),
                  ),
                ),

                // Pie de acciones
                _buildFooter(context, isPaused, isDark, borderColor, isCompactDialog),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isPaused,
    Color alertBg,
    Color alertTextColor,
    String alertLabel,
    bool isMobile,
  ) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF0055A5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.event_repeat_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  schedule.id,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    schedule.frequency.label,
                    style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: 'Cerrar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    schedule.title.isNotEmpty ? schedule.title : schedule.maintenanceType,
                    style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaused ? Colors.white24 : alertBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaused ? 'Plan Pausado' : alertLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPaused ? Colors.white : alertTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
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
            child: const Icon(Icons.event_repeat_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      schedule.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        schedule.frequency.label,
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  schedule.title.isNotEmpty ? schedule.title : schedule.maintenanceType,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Badge Semáforo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isPaused ? Colors.white24 : alertBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isPaused ? 'Plan Pausado' : alertLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isPaused ? Colors.white : alertTextColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow(String nextDateStr, bool isDark, Color borderColor, Color sectionBg, bool isMobile) {
    final tile1 = _buildKpiTile(
      label: 'Próxima Ejecución',
      value: nextDateStr,
      subtitle: schedule.daysRemaining < 0
          ? 'Vencido hace ${schedule.daysRemaining.abs()} d'
          : 'En ${schedule.daysRemaining} días',
      icon: Icons.calendar_today_rounded,
      color: schedule.daysRemaining < 0 ? const Color(0xFFDC2626) : const Color(0xFF0055A5),
      isDark: isDark,
      borderColor: borderColor,
      sectionBg: sectionBg,
    );
    final tile2 = _buildKpiTile(
      label: 'Frecuencia Plan',
      value: schedule.frequency.label,
      subtitle: 'Ciclo programado',
      icon: Icons.update_rounded,
      color: const Color(0xFF0284C7),
      isDark: isDark,
      borderColor: borderColor,
      sectionBg: sectionBg,
    );
    final tile3 = _buildKpiTile(
      label: 'Componentes',
      value: '${schedule.activities.length} hijos',
      subtitle: 'Tareas desglosadas',
      icon: Icons.account_tree_outlined,
      color: const Color(0xFF7C3AED),
      isDark: isDark,
      borderColor: borderColor,
      sectionBg: sectionBg,
    );
    final tile4 = _buildKpiTile(
      label: 'Horas Estimadas',
      value: schedule.estimatedHours != null ? '${schedule.estimatedHours} h' : '—',
      subtitle: 'Por ejecución',
      icon: Icons.timer_outlined,
      color: const Color(0xFF059669),
      isDark: isDark,
      borderColor: borderColor,
      sectionBg: sectionBg,
    );

    if (isMobile) {
      return Column(
        children: [
          Row(children: [tile1, const SizedBox(width: 10), tile2]),
          const SizedBox(height: 10),
          Row(children: [tile3, const SizedBox(width: 10), tile4]),
        ],
      );
    }

    return Row(
      children: [
        tile1,
        const SizedBox(width: 10),
        tile2,
        const SizedBox(width: 10),
        tile3,
        const SizedBox(width: 10),
        tile4,
      ],
    );
  }

  Widget _buildKpiTile({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color borderColor,
    required Color sectionBg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sectionBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0055A5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetInfoCard(
    String startDateStr,
    String nextDateStr,
    bool isDark,
    Color borderColor,
    Color sectionBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Equipo Principal:', style: TextStyle(fontSize: 11, color: textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      '${schedule.assetId} · ${schedule.assetName.isNotEmpty ? schedule.assetName : "Equipo principal"}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0055A5).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF0055A5)),
                    const SizedBox(width: 4),
                    Text(
                      schedule.areaName.isNotEmpty ? schedule.areaName : schedule.areaId,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0055A5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tipo de Intervención:', style: TextStyle(fontSize: 11, color: textSecondary)),
                    Text(
                      schedule.maintenanceType.isNotEmpty ? schedule.maintenanceType : 'Preventivo General',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fecha de Inicio Base:', style: TextStyle(fontSize: 11, color: textSecondary)),
                    Text(startDateStr, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
                  ],
                ),
              ),
              if (schedule.lastWorkOrderId != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Última OT Ejecutada:', style: TextStyle(fontSize: 11, color: textSecondary)),
                      Text(
                        schedule.lastWorkOrderId!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0055A5),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (schedule.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Objetivo / Procedimiento General:', style: TextStyle(fontSize: 11, color: textSecondary)),
            const SizedBox(height: 2),
            Text(schedule.description, style: TextStyle(fontSize: 12.5, color: textPrimary)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyActivitiesNotice(bool isDark, Color borderColor, Color sectionBg, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Este plan preventivo aplica a nivel global sobre el equipo principal (no tiene actividades hijas desglosadas por componente).',
              style: TextStyle(fontSize: 12.5, color: textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    PreventiveChildActivity act,
    bool isDark,
    Color borderColor,
    Color sectionBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    final (actBg, actFg, actStatus) = switch (act.alertLevel) {
      PreventiveAlertLevel.overdue => (
          const Color(0xFFFEE2E2),
          const Color(0xFFDC2626),
          'Vencido (${act.daysRemaining.abs()}d)',
        ),
      PreventiveAlertLevel.urgent => (
          const Color(0xFFFFEDD5),
          const Color(0xFFC2410C),
          'Urgente (${act.daysRemaining}d)',
        ),
      PreventiveAlertLevel.upcoming => (
          const Color(0xFFFEF3C7),
          const Color(0xFFB45309),
          'Próximo (${act.daysRemaining}d)',
        ),
      PreventiveAlertLevel.onSchedule => (
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
          'Al día (${act.daysRemaining}d)',
        ),
    };

    final actNextStr = '${act.nextDate.day.toString().padLeft(2, "0")}/'
        '${act.nextDate.month.toString().padLeft(2, "0")}/'
        '${act.nextDate.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0055A5).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.build_outlined, size: 16, color: Color(0xFF0055A5)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${act.childAssetId} · ${act.childAssetName}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    Text(
                      'Nivel: ${act.childAssetLevel}',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
              ),
              // Chip Frecuencia
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0055A5).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  act.frequencyLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0055A5)),
                ),
              ),
              const SizedBox(width: 8),
              // Chip Semáforo individual
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: actBg,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  actStatus,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: actFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 8),

          // Tarea
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tarea / Procedimiento:', style: TextStyle(fontSize: 11, color: textSecondary)),
                    const SizedBox(height: 2),
                    Text(act.description, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: textPrimary)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Próximo Mantenimiento:', style: TextStyle(fontSize: 11, color: textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      actNextStr,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: act.isOverdue ? const Color(0xFFDC2626) : const Color(0xFF0055A5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Materiales de la actividad
          if (act.materials.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Insumos / Refacciones requeridas:', style: TextStyle(fontSize: 11, color: textSecondary)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: act.materials.map((m) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    '${m.quantity} ${m.unit} - ${m.name}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textPrimary),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaterialsWrap(
    List<PreventiveMaterial> materials,
    bool isDark,
    Color borderColor,
    Color sectionBg,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: materials.map((m) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.handyman_outlined, size: 14, color: Color(0xFF0055A5)),
                const SizedBox(width: 6),
                Text(
                  '${m.quantity} ${m.unit} - ${m.name}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAmendmentCard(bool isDark, Color borderColor, Color textPrimary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                'Documento de Autorización: ${schedule.amendmentDocNumber}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
              ),
            ],
          ),
          if (schedule.amendedBy != null) ...[
            const SizedBox(height: 4),
            Text(
              'Autorizado por: ${schedule.amendedBy}',
              style: TextStyle(fontSize: 11.5, color: textPrimary),
            ),
          ],
          if (schedule.amendmentReason != null && schedule.amendmentReason!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Motivo de la Enmienda: ${schedule.amendmentReason}',
              style: TextStyle(fontSize: 11.5, color: textPrimary, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isPaused, bool isDark, Color borderColor, bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canGenerateOt && !isPaused && onGenerateOt != null)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onGenerateOt?.call();
                },
                icon: const Icon(Icons.assignment_add, size: 16),
                label: const Text('Generar OT Preventiva'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0055A5),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            if (canGenerateOt && !isPaused && onGenerateOt != null)
              const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  child: const Text('Cerrar'),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (isAdmin && onToggleStatus != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onToggleStatus?.call();
                        },
                        icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 14),
                        label: Text(isPaused ? 'Reanudar' : 'Pausar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    if (isAdmin && onAmend != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onAmend?.call();
                        },
                        icon: const Icon(Icons.edit_note, size: 14),
                        label: const Text('Modificar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isAdmin && onToggleStatus != null)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onToggleStatus?.call();
                  },
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 16),
                  label: Text(isPaused ? 'Reanudar Plan' : 'Pausar Plan'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              if (isAdmin && onAmend != null)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onAmend?.call();
                  },
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('Modificar (Gerencial)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              if (canGenerateOt && !isPaused && onGenerateOt != null)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onGenerateOt?.call();
                  },
                  icon: const Icon(Icons.assignment_add, size: 16),
                  label: const Text('Generar OT Preventiva'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0055A5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

