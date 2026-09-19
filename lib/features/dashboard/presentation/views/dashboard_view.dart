import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key, this.onNavigateToSection});

  final ValueChanged<String>? onNavigateToSection;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DashboardViewModel>().loadStats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = context.watch<AuthViewModel>().currentUser;
    final vm = context.watch<DashboardViewModel>();
    final stats = vm.stats;

    return RefreshIndicator(
      onRefresh: () async => context.read<DashboardViewModel>().loadStats(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de Bienvenida
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bienvenido, ${user?.displayName ?? user?.username ?? 'Usuario'}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Panel de Indicadores y Trazabilidad Operativa en Tiempo Real',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => context.read<DashboardViewModel>().loadStats(),
                  tooltip: 'Actualizar métricas',
                  icon: const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (vm.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (vm.errorMessage.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 40, color: colors.error),
                      const SizedBox(height: 8),
                      Text('Error: ${vm.errorMessage}', style: TextStyle(color: colors.error)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => vm.loadStats(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Fila 1: Indicadores Principales de Operación
              _SummaryCardsRow(
                cards: [
                  _SummaryCard(
                    icon: Icons.precision_manufacturing_outlined,
                    label: 'Activos Operativos',
                    value: '${stats?.totalAssets ?? 0}',
                    subtitle: 'Jerarquía completa',
                    color: const Color(0xFF0D9488),
                    onTap: () => widget.onNavigateToSection?.call('assets'),
                  ),
                  _SummaryCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'Averías Abiertas',
                    value: '${stats?.openBreakdowns ?? 0}',
                    subtitle: 'Reportadas / En Proceso',
                    color: (stats?.openBreakdowns ?? 0) > 0 ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                    onTap: () => widget.onNavigateToSection?.call('breakdownReports'),
                  ),
                  _SummaryCard(
                    icon: Icons.event_repeat_outlined,
                    label: 'Planes Preventivos',
                    value: '${stats?.activeSchedules ?? 0}',
                    subtitle: '${stats?.urgentSchedules ?? 0} urgente(s)',
                    color: const Color(0xFF0284C7),
                    onTap: () => widget.onNavigateToSection?.call('preventive'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Fila 2: Órdenes de Trabajo y Kardex
              _SummaryCardsRow(
                cards: [
                  _SummaryCard(
                    icon: Icons.pending_actions_outlined,
                    label: 'OTs Pendientes',
                    value: '${stats?.pendingWorkOrders ?? 0}',
                    subtitle: 'Por iniciar ejecución',
                    color: const Color(0xFFD97706),
                    onTap: () => widget.onNavigateToSection?.call('workOrders'),
                  ),
                  _SummaryCard(
                    icon: Icons.autorenew_outlined,
                    label: 'OTs En Progreso',
                    value: '${stats?.inProgressWorkOrders ?? 0}',
                    subtitle: 'En ejecución en planta',
                    color: const Color(0xFF2563EB),
                    onTap: () => widget.onNavigateToSection?.call('workOrders'),
                  ),
                  _SummaryCard(
                    icon: Icons.check_circle_outline,
                    label: 'OTs Completadas',
                    value: '${stats?.completedWorkOrders ?? 0}',
                    subtitle: 'Cerradas con éxito',
                    color: const Color(0xFF16A34A),
                    onTap: () => widget.onNavigateToSection?.call('workOrders'),
                  ),
                  _SummaryCard(
                    icon: Icons.history_edu_outlined,
                    label: 'Trazabilidad Kardex',
                    value: '${stats?.totalKardexLogs ?? 0}',
                    subtitle: 'Eventos inmutables',
                    color: const Color(0xFF7C3AED),
                    onTap: () => widget.onNavigateToSection?.call('kardex'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Tarjeta de Salud y Cumplimiento Preventivo (PM Compliance)
              _buildComplianceCard(context, stats?.pmComplianceRate ?? 100.0),

              const SizedBox(height: 20),

              // Tarjeta de Trazabilidad e Integridad del Sistema
              _buildSystemHealthCard(context, stats),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceCard(BuildContext context, double rate) {
    final theme = Theme.of(context);
    final isGood = rate >= 80.0;
    final isMedium = rate >= 60.0 && rate < 80.0;
    final color = isGood ? const Color(0xFF16A34A) : (isMedium ? const Color(0xFFD97706) : const Color(0xFFDC2626));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 22, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cumplimiento del Programa Preventivo (PM Compliance)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${rate.toStringAsFixed(1)}%',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (rate / 100.0).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isGood
                  ? 'La tasa de ejecución y cierre de órdenes preventivas se mantiene en niveles óptimos.'
                  : 'Se recomienda atender las órdenes preventivas pendientes para elevar el índice de confiabilidad.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHealthCard(BuildContext context, dynamic stats) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 20, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trazabilidad e Integridad de Mantenimiento',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Toda acción sobre activos, órdenes de trabajo, traspasos y averías queda registrada de forma inmutable '
              'en la Bitácora Kardex bajo arquitectura transaccional en SQL Server.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCardsRow extends StatelessWidget {
  const _SummaryCardsRow({required this.cards});

  final List<_SummaryCard> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 500
            ? 1
            : (constraints.maxWidth < 900 ? 2 : cards.length);
        const spacing = AppSpacing.md;
        final totalSpacing = spacing * (columns - 1);
        final itemWidth = (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(width: itemWidth, child: card),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.15)),
      ),
      color: color.withValues(alpha: 0.04),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.arrow_forward_ios, size: 12, color: color.withValues(alpha: 0.5)),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
