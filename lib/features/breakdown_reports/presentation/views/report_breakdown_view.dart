import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../assets/domain/entities/area.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/breakdown_report.dart';
import '../viewmodels/report_breakdown_viewmodel.dart';

/// Formulario ejecutivo y sofisticado para reportar averías e incidencias operativas.
/// Incluye buscador modal de áreas y equipos, diseño corporativo sobrio y trazabilidad.
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: const Color(0xFF0F766E),
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Avería registrada exitosamente. Notificación enviada al panel de mantenimiento.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: const Color(0xFFB91C1C),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _viewModel.errorMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
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

  void _openAreaSearchModal(BuildContext context, ReportBreakdownViewModel vm) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _AreaSearchDialog(
        areas: vm.areas,
        selectedAreaId: vm.selectedAreaId,
        onAreaSelected: (selectedArea) {
          vm.selectArea(selectedArea.id);
        },
      ),
    );
  }

  void _openAssetSearchModal(BuildContext context, ReportBreakdownViewModel vm) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _AssetSearchDialog(
        assets: vm.assets,
        selectedAssetId: vm.selectedAssetId,
        getOpenReport: vm.getOpenReportForAsset,
        onAssetSelected: (selectedAsset) {
          vm.selectAsset(selectedAsset.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch<ReportBreakdownViewModel>();
    final isDark = theme.brightness == Brightness.dark;

    final selectedArea = vm.selectedAreaId != null
        ? vm.areas.where((a) => a.id == vm.selectedAreaId).firstOrNull
        : null;

    final selectedAsset = vm.selectedAssetId != null
        ? vm.assets.where((a) => a.id == vm.selectedAssetId).firstOrNull
        : null;

    final isAssetBlocked = selectedAsset != null && vm.isAssetPending(selectedAsset.id);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            children: [
              // Encabezado Corporativo Formal (Estilo Ficha Ejecutiva)
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 4,
                      color: theme.colorScheme.primary,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Reporte de Avería o Incidencia Técnica',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'Mantenimiento Correctivo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0369A1),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Formulario oficial de notificación de fallas operativas. Las incidencias reportadas alertan de inmediato a la jefatura de mantenimiento y quedan registradas con trazabilidad en la bitácora Kardex.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Contenedor Principal del Formulario
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // SECCIÓN 1: UBICACIÓN Y EQUIPO
                    // ==========================================
                    _buildSectionHeader(
                      stepNumber: '01',
                      title: 'Ubicación y Equipo Afectado',
                      subtitle: 'Selecciona o busca el área operativa y el activo que presenta la anomalía.',
                      theme: theme,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 18),

                    // Campo de Área con Buscador Integrado
                    const Text(
                      'ÁREA OPERATIVA DE UBICACIÓN *',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildAreaSelectorCard(
                      context: context,
                      theme: theme,
                      vm: vm,
                      selectedArea: selectedArea,
                      isDark: isDark,
                      borderColor: borderColor,
                      onTapSearch: () => _openAreaSearchModal(context, vm),
                    ),

                    const SizedBox(height: 20),

                    // Campo de Activo / Equipo Afectado
                    const Text(
                      'ACTIVO O EQUIPO AFECTADO *',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (vm.selectedAreaId == null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          'Selecciona primero un área operativa para desplegar los equipos y maquinarias correspondientes.',
                          style: TextStyle(fontSize: 12, color: secondaryText),
                        ),
                      )
                    else if (vm.isLoadingAssets)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Consultando catálogo de equipos del área ${selectedArea?.name ?? ''}...',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (vm.assets.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Text(
                          'No se encontraron equipos o activos operativos registrados en esta área.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      _buildAssetSelectorCard(
                        context: context,
                        theme: theme,
                        vm: vm,
                        selectedAsset: selectedAsset,
                        isDark: isDark,
                        borderColor: borderColor,
                        onTapSearch: () => _openAssetSearchModal(context, vm),
                      ),

                    if (selectedAsset != null && vm.isAssetPending(selectedAsset.id)) ...[
                      const SizedBox(height: 10),
                      Builder(builder: (context) {
                        final pendingReport = vm.getOpenReportForAsset(selectedAsset.id);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Avería activa en este activo (Folio #${pendingReport?.id ?? ""})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Este equipo ya cuenta con un reporte de avería en estado "${pendingReport?.statusLabel ?? "Reportada"}". '
                                'Por norma operativa, no se puede generar un reporte duplicado del mismo equipo hasta que el actual sea resuelto o rechazado.',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.3),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 28),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 24),

                    // ==========================================
                    // SECCIÓN 2: SEVERIDAD Y CRITICIDAD
                    // ==========================================
                    _buildSectionHeader(
                      stepNumber: '02',
                      title: 'Criticidad y Nivel de Severidad',
                      subtitle: 'Evalúa el impacto inmediato de la falla sobre la producción o seguridad.',
                      theme: theme,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 560;
                        final cards = [
                          _SeverityExecutiveCard(
                            severity: BreakdownSeverity.low,
                            badgeText: 'Nivel 1',
                            label: 'Baja Prioridad',
                            desc: 'Falla leve o ajuste menor. No detiene la operación ni compromete inocuidad.',
                            accentColor: const Color(0xFF059669),
                            isSelected: vm.severity == BreakdownSeverity.low,
                            onTap: () => vm.setSeverity(BreakdownSeverity.low),
                            isDark: isDark,
                          ),
                          _SeverityExecutiveCard(
                            severity: BreakdownSeverity.medium,
                            badgeText: 'Nivel 2',
                            label: 'Media / Atención',
                            desc: 'Rendimiento degradado o riesgo potencial. Requiere atención técnica pronta.',
                            accentColor: const Color(0xFFD97706),
                            isSelected: vm.severity == BreakdownSeverity.medium,
                            onTap: () => vm.setSeverity(BreakdownSeverity.medium),
                            isDark: isDark,
                          ),
                          _SeverityExecutiveCard(
                            severity: BreakdownSeverity.high,
                            badgeText: 'Nivel 3',
                            label: 'Alta / Urgente',
                            desc: 'Paro total de equipo o línea de producción. Riesgo operativo inminente.',
                            accentColor: const Color(0xFFDC2626),
                            isSelected: vm.severity == BreakdownSeverity.high,
                            onTap: () => vm.setSeverity(BreakdownSeverity.high),
                            isDark: isDark,
                          ),
                        ];

                        if (isCompact) {
                          return Column(
                            children: [
                              for (int i = 0; i < cards.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                cards[i],
                              ],
                            ],
                          );
                        }

                        return Row(
                          children: [
                            for (int i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Expanded(child: cards[i]),
                            ],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 28),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 24),

                    // ==========================================
                    // SECCIÓN 3: DESCRIPCIÓN DEL PROBLEMA
                    // ==========================================
                    _buildSectionHeader(
                      stepNumber: '03',
                      title: 'Descripción del Evento o Anomalía',
                      subtitle: 'Detalla las observaciones y comportamiento anómalo detectado en la máquina.',
                      theme: theme,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      key: const Key('breakdown-description'),
                      controller: descController,
                      maxLines: 4,
                      minLines: 3,
                      onChanged: vm.setDescription,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Describe la falla con el mayor detalle posible: ruidos atípicos, vibraciones, mensajes o alarmas en pantalla, fugas de aceite o agua, componentes trabados, humo...',
                        hintStyle: TextStyle(fontSize: 12.5, color: secondaryText.withValues(alpha: 0.8)),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Esta información servirá como diagnóstico inicial para que el Jefe de Mantenimiento emita y asigne la Orden de Trabajo correspondiente.',
                      style: TextStyle(fontSize: 11.5, color: secondaryText),
                    ),

                    const SizedBox(height: 32),

                    // Botón de Envío Oficial
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        key: const Key('breakdown-submit'),
                        onPressed: (vm.isSubmitting || isAssetBlocked) ? null : onSubmit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0055A5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: vm.isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Registrar Reporte de Avería',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Encabezado de paso formal y numerado
  Widget _buildSectionHeader({
    required String stepNumber,
    required String title,
    required String subtitle,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF0055A5).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF0055A5).withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Text(
            stepNumber,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0055A5),
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Selector de Área sofisticado con visualización y botón de búsqueda
  Widget _buildAreaSelectorCard({
    required BuildContext context,
    required ThemeData theme,
    required ReportBreakdownViewModel vm,
    required Area? selectedArea,
    required bool isDark,
    required Color borderColor,
    required VoidCallback onTapSearch,
  }) {
    final hasArea = selectedArea != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasArea ? const Color(0xFF0055A5).withValues(alpha: 0.6) : borderColor,
          width: hasArea ? 1.2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: vm.isLoadingAreas ? null : onTapSearch,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (!hasArea) ...[
                  Expanded(
                    child: Text(
                      vm.isLoadingAreas
                          ? 'Cargando catálogo de áreas...'
                          : 'Buscar o seleccionar área operativa...',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF64748B).withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF0055A5).withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      selectedArea.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0055A5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedArea.name,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (selectedArea.costCenter.isNotEmpty)
                          Text(
                            'Centro de Costos: ${selectedArea.costCenter}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: vm.isLoadingAreas ? null : onTapSearch,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0055A5),
                    side: BorderSide(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.3),
                      width: 0.9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  child: Text(
                    hasArea ? 'Cambiar' : 'Buscar Área',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Selector de Activo / Equipo sofisticado
  Widget _buildAssetSelectorCard({
    required BuildContext context,
    required ThemeData theme,
    required ReportBreakdownViewModel vm,
    required Asset? selectedAsset,
    required bool isDark,
    required Color borderColor,
    required VoidCallback onTapSearch,
  }) {
    final hasAsset = selectedAsset != null;
    final hasSerial = hasAsset && selectedAsset.serial != null && selectedAsset.serial!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasAsset ? const Color(0xFF0055A5).withValues(alpha: 0.6) : borderColor,
          width: hasAsset ? 1.2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapSearch,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (!hasAsset) ...[
                  Expanded(
                    child: Text(
                      'Buscar o seleccionar equipo (${vm.assets.length} disponibles)...',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF64748B).withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF0055A5).withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      selectedAsset.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0055A5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedAsset.name,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasSerial)
                          Text(
                            'Serie: ${selectedAsset.serial!}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onTapSearch,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0055A5),
                    side: BorderSide(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.3),
                      width: 0.9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  child: Text(
                    hasAsset ? 'Cambiar' : 'Buscar Equipo',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo Modal Ejecutivo para Búsqueda en Tiempo Real de Áreas Operativas
class _AreaSearchDialog extends StatefulWidget {
  const _AreaSearchDialog({
    required this.areas,
    required this.selectedAreaId,
    required this.onAreaSelected,
  });

  final List<Area> areas;
  final String? selectedAreaId;
  final ValueChanged<Area> onAreaSelected;

  @override
  State<_AreaSearchDialog> createState() => _AreaSearchDialogState();
}

class _AreaSearchDialogState extends State<_AreaSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _clean(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cleanQuery = _clean(_query);

    final filtered = widget.areas.where((a) {
      if (cleanQuery.isEmpty) return true;
      final idClean = _clean(a.id);
      final nameClean = _clean(a.name);
      final ccClean = _clean(a.costCenter);
      return idClean.contains(cleanQuery) ||
          nameClean.contains(cleanQuery) ||
          ccClean.contains(cleanQuery);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.business_outlined,
                      color: Color(0xFF0055A5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar Área Operativa',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Filtra por código (ej. A003) o por nombre de área',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (val) => setState(() => _query = val),
                decoration: InputDecoration(
                  hintText: 'Escribe el código o nombre del área...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0055A5), width: 1.5),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mostrando ${filtered.length} de ${widget.areas.length} áreas operativas',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              'No se encontraron áreas coincidentes con "$_query"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                      itemBuilder: (context, idx) {
                        final area = filtered[idx];
                        final isSelected = area.id == widget.selectedAreaId;

                        return Material(
                          color: isSelected
                              ? const Color(0xFF0055A5).withValues(alpha: 0.07)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0055A5)
                                    : const Color(0xFF0055A5).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                area.id,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF0055A5),
                                ),
                              ),
                            ),
                            title: Text(
                              area.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            subtitle: area.costCenter.isNotEmpty
                                ? Text(
                                    'CC: ${area.costCenter}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  )
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF0055A5), size: 18)
                                : const Icon(Icons.chevron_right_rounded,
                                    color: Color(0xFFCBD5E1), size: 18),
                            onTap: () {
                              widget.onAreaSelected(area);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo Modal Ejecutivo para Búsqueda en Tiempo Real de Equipos / Activos
class _AssetSearchDialog extends StatefulWidget {
  const _AssetSearchDialog({
    required this.assets,
    required this.selectedAssetId,
    required this.onAssetSelected,
    this.getOpenReport,
  });

  final List<Asset> assets;
  final String? selectedAssetId;
  final ValueChanged<Asset> onAssetSelected;
  final BreakdownReport? Function(String assetId)? getOpenReport;

  @override
  State<_AssetSearchDialog> createState() => _AssetSearchDialogState();
}

class _AssetSearchDialogState extends State<_AssetSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _clean(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cleanQuery = _clean(_query);

    final filtered = widget.assets.where((a) {
      if (cleanQuery.isEmpty) return true;
      final idClean = _clean(a.id);
      final nameClean = _clean(a.name);
      final serialClean = _clean(a.serial ?? '');
      return idClean.contains(cleanQuery) ||
          nameClean.contains(cleanQuery) ||
          serialClean.contains(cleanQuery);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.settings_suggest_outlined,
                      color: Color(0xFF0055A5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar Equipo Afectado',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Filtra por código de activo, nombre de equipo o serie',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (val) => setState(() => _query = val),
                decoration: InputDecoration(
                  hintText: 'Escribe el código o nombre del equipo...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0055A5), width: 1.5),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mostrando ${filtered.length} de ${widget.assets.length} equipos disponibles',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              'No se encontraron equipos coincidentes con "$_query"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                      itemBuilder: (context, idx) {
                        final asset = filtered[idx];
                        final isSelected = asset.id == widget.selectedAssetId;
                        final hasSerial = asset.serial != null && asset.serial!.isNotEmpty;

                        return Material(
                          color: isSelected
                              ? const Color(0xFF0055A5).withValues(alpha: 0.07)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0055A5)
                                    : const Color(0xFF0055A5).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                asset.id,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF0055A5),
                                ),
                              ),
                            ),
                            title: Text(
                              asset.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            subtitle: hasSerial
                                ? Text(
                                    'Serie: ${asset.serial!}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Builder(builder: (context) {
                                  final openReport = widget.getOpenReport?.call(asset.id);
                                  if (openReport == null) return const SizedBox.shrink();
                                  return Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFF59E0B)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFB45309)),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Avería #${openReport.id}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF0055A5), size: 18)
                                else
                                  const Icon(Icons.chevron_right_rounded,
                                      color: Color(0xFFCBD5E1), size: 18),
                              ],
                            ),
                            onTap: () {
                              widget.onAssetSelected(asset);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta Ejecutiva y Formal de Severidad / Criticidad
class _SeverityExecutiveCard extends StatelessWidget {
  const _SeverityExecutiveCard({
    required this.severity,
    required this.badgeText,
    required this.label,
    required this.desc,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final BreakdownSeverity severity;
  final String badgeText;
  final String label;
  final String desc;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: isDark ? 0.12 : 0.05)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 16,
                    color: isSelected ? accentColor : const Color(0xFF94A3B8),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
