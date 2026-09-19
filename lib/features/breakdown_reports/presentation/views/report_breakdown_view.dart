import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../domain/entities/breakdown_report.dart';
import '../viewmodels/report_breakdown_viewmodel.dart';

/// Formulario ejecutivo moderno para reportar averías e incidencias de equipos.
class ReportBreakdownView extends StatefulWidget {
  const ReportBreakdownView({super.key});

  @override
  State<ReportBreakdownView> createState() => _ReportBreakdownViewState();
}

class _ReportBreakdownViewState extends State<ReportBreakdownView> {
  late final ReportBreakdownViewModel _viewModel =
      getIt<ReportBreakdownViewModel>();
  final TextEditingController _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewModel.loadAreas();
    });
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final ok = await _viewModel.submit(
      userId: user.userId,
      userName: user.username,
    );
    if (!mounted) return;

    if (ok) {
      _descCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFF16A34A),
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Avería reportada exitosamente. Registrada en el Kardex.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_viewModel.errorMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFFDC2626),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _viewModel.errorMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReportBreakdownViewModel>.value(
      value: _viewModel,
      child: _ReportForm(
        onSubmit: _submit,
        descController: _descCtrl,
      ),
    );
  }
}

class _ReportForm extends StatelessWidget {
  const _ReportForm({
    required this.onSubmit,
    required this.descController,
  });

  final Future<void> Function() onSubmit;
  final TextEditingController descController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch<ReportBreakdownViewModel>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // Header Banner Principal
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.08),
                      theme.colorScheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Reportar Avería o Incidencia',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Mantenimiento Correctivo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Selecciona el área de ubicación, el equipo afectado y especifica la severidad. '
                            'El reporte quedará disponible de inmediato para los supervisores y el equipo de mantenimiento.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Tarjeta Formulario Unificado
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade300, width: 0.8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bloque 1: Ubicación y Equipo
                      _buildSectionTitle(
                        icon: Icons.precision_manufacturing_outlined,
                        title: '1. Ubicación y Equipo Afectado',
                        theme: theme,
                      ),
                      const SizedBox(height: 14),

                      // Selector de Área
                      DropdownButtonFormField<String>(
                        key: const Key('breakdown-area'),
                        value: vm.selectedAreaId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Área de Ubicación *',
                          hintText: vm.isLoadingAreas
                              ? 'Cargando áreas disponibles...'
                              : 'Selecciona el área operativa',
                          prefixIcon: const Icon(Icons.business_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: [
                          for (final area in vm.areas)
                            DropdownMenuItem(
                              value: area.id,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      area.id,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      area.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        onChanged: vm.isLoadingAreas
                            ? null
                            : (value) {
                                if (value != null) vm.selectArea(value);
                              },
                      ),

                      const SizedBox(height: 16),

                      // Selector de Activo
                      if (vm.selectedAreaId == null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Selecciona un área para listar sus equipos y componentes.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (vm.isLoadingAssets)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Cargando activos y equipos del área...',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (vm.assets.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_outlined, size: 18, color: Color(0xFFD97706)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Esta área no tiene equipos activos registrados.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey('breakdown-asset-${vm.selectedAreaId}'),
                          value: vm.selectedAssetId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Activo / Equipo Afectado *',
                            hintText: 'Selecciona el equipo que presenta la falla',
                            prefixIcon: const Icon(Icons.settings_suggest_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: [
                            for (final Asset asset in vm.assets)
                              DropdownMenuItem(
                                value: asset.id,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blueGrey.shade200),
                                      ),
                                      child: Text(
                                        asset.id,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        asset.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          onChanged: (value) => vm.selectAsset(value),
                        ),

                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 20),

                      // Bloque 2: Severidad de la Avería
                      _buildSectionTitle(
                        icon: Icons.speed_outlined,
                        title: '2. Nivel de Severidad / Urgencia',
                        theme: theme,
                      ),
                      const SizedBox(height: 12),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 420;
                          final cards = [
                            _SeverityCard(
                              severity: BreakdownSeverity.low,
                              label: 'Baja',
                              desc: 'Falla leve / Operación normal',
                              icon: Icons.info_outline,
                              color: const Color(0xFF16A34A),
                              isSelected: vm.severity == BreakdownSeverity.low,
                              onTap: () => vm.setSeverity(BreakdownSeverity.low),
                            ),
                            _SeverityCard(
                              severity: BreakdownSeverity.medium,
                              label: 'Media',
                              desc: 'Afecta rendimiento parcial',
                              icon: Icons.warning_amber_rounded,
                              color: const Color(0xFFD97706),
                              isSelected: vm.severity == BreakdownSeverity.medium,
                              onTap: () => vm.setSeverity(BreakdownSeverity.medium),
                            ),
                            _SeverityCard(
                              severity: BreakdownSeverity.high,
                              label: 'Alta',
                              desc: 'Paro de equipo / Urgente',
                              icon: Icons.error_outline,
                              color: const Color(0xFFDC2626),
                              isSelected: vm.severity == BreakdownSeverity.high,
                              onTap: () => vm.setSeverity(BreakdownSeverity.high),
                            ),
                          ];

                          if (isCompact) {
                            return Column(
                              children: [
                                for (int i = 0; i < cards.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 8),
                                  cards[i],
                                ],
                              ],
                            );
                          }

                          return Row(
                            children: [
                              for (int i = 0; i < cards.length; i++) ...[
                                if (i > 0) const SizedBox(width: 10),
                                Expanded(child: cards[i]),
                              ],
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 20),

                      // Bloque 3: Detalle y Descripción
                      _buildSectionTitle(
                        icon: Icons.description_outlined,
                        title: '3. Descripción del Problema',
                        theme: theme,
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        key: const Key('breakdown-description'),
                        controller: descController,
                        maxLines: 4,
                        minLines: 3,
                        onChanged: vm.setDescription,
                        decoration: InputDecoration(
                          labelText: 'Detalles de la avería *',
                          hintText: 'Describe el problema: ruidos anómalos, fugas de aceite, recalentamiento, fallas eléctricas...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Proporciona la mayor cantidad de detalles posible para facilitar el diagnóstico del personal técnico.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      ),

                      const SizedBox(height: 28),

                      // Botón de Envío
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton.icon(
                          key: const Key('breakdown-submit'),
                          onPressed: vm.isSubmitting ? null : onSubmit,
                          icon: vm.isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            vm.isSubmitting ? 'Enviando reporte...' : 'Enviar Reporte de Avería',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta interactiva de severidad con estilo moderno y badges de color.
class _SeverityCard extends StatelessWidget {
  const _SeverityCard({
    required this.severity,
    required this.label,
    required this.desc,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final BreakdownSeverity severity;
  final String label;
  final String desc;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.8 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle_rounded, size: 16, color: color),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.grey.shade700,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
