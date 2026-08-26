import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/widgets/app_dialog.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../work_orders/presentation/views/work_order_create_view.dart';
import '../../domain/entities/breakdown_report.dart';
import '../viewmodels/breakdown_reports_viewmodel.dart';

enum _ReportTab { open, resolved, rejected }

class BreakdownReportsView extends StatefulWidget {
  const BreakdownReportsView({super.key});

  @override
  State<BreakdownReportsView> createState() => _BreakdownReportsViewState();
}

class _BreakdownReportsViewState extends State<BreakdownReportsView> {
  _ReportTab _tab = _ReportTab.open;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    context.read<BreakdownReportsViewModel>().load(
          startDate: _startDate,
          endDate: _endDate,
        );
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      helpText: 'Seleccionar Rango de Fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
      _loadData();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadData();
  }

  Future<void> _generateWorkOrder(BreakdownReport report) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => WorkOrderCreateView(report: report),
      ),
    );

    if (created == true && mounted) {
      _loadData();
    }
  }

  Future<void> _confirmResolve(BreakdownReport report) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Marcar avería como resuelta?'),
        content: Text(
          'Se marcará como resuelta la avería del equipo '
          '"${report.assetId} — ${report.assetName}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Resolver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final viewModel = context.read<BreakdownReportsViewModel>();
    final ok = await viewModel.resolve(
      report: report,
      resolvedByUserId: user.userId,
      resolvedByUserName: user.username,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Avería marcada como resuelta.' : 'Error: ${viewModel.errorMessage}',
        ),
      ),
    );
  }

  Future<void> _confirmReject(BreakdownReport report) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectReportDialog(report: report),
    );
    if (reason == null || !mounted) return;

    final viewModel = context.read<BreakdownReportsViewModel>();
    final ok = await viewModel.reject(
      report: report,
      reason: reason,
      rejectedByUserId: user.userId,
      rejectedByUserName: user.username,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Reporte rechazado.' : 'Error: ${viewModel.errorMessage}',
        ),
      ),
    );
  }

  List<BreakdownReport> _filterReports(List<BreakdownReport> list) {
    if (_searchQuery.isEmpty) return list;

    return list.where((r) {
      final assetId = r.assetId.toLowerCase();
      final assetName = r.assetName.toLowerCase();
      final areaId = r.areaId.toLowerCase();
      final desc = r.description.toLowerCase();
      final reporter = r.reportedByUserName.toLowerCase();
      final ot = (r.workOrderId ?? '').toLowerCase();

      return assetId.contains(_searchQuery) ||
          assetName.contains(_searchQuery) ||
          areaId.contains(_searchQuery) ||
          desc.contains(_searchQuery) ||
          reporter.contains(_searchQuery) ||
          ot.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BreakdownReportsViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final canCreateOt = authVm.hasPermission('breakdown.manage');
    final canResolve = authVm.hasPermission('breakdown.manage');
    final canReject = authVm.hasPermission('breakdown.manage');

    final dateLabel = _startDate == null
        ? 'Filtrar fecha'
        : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}';

    final currentTabReports = switch (_tab) {
      _ReportTab.open => vm.openReports,
      _ReportTab.resolved => vm.resolvedReports,
      _ReportTab.rejected => vm.rejectedReports,
    };

    final filteredReports = _filterReports(currentTabReports);

    return Scaffold(
      body: Column(
        children: [
          // Barra de Control Responsiva (Mobile & Desktop)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;

                final segmented = SegmentedButton<_ReportTab>(
                  segments: [
                    ButtonSegment(
                      value: _ReportTab.open,
                      label: Text('Abiertas (${vm.openReports.length})'),
                    ),
                    ButtonSegment(
                      value: _ReportTab.resolved,
                      label: Text('Resueltas (${vm.resolvedReports.length})'),
                    ),
                    ButtonSegment(
                      value: _ReportTab.rejected,
                      label: Text('Rechazadas (${vm.rejectedReports.length})'),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (set) => setState(() => _tab = set.first),
                );

                final searchField = TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por equipo, código o descripción...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );

                final dateChip = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ActionChip(
                      avatar: Icon(
                        Icons.date_range,
                        size: 16,
                        color: _startDate != null ? Theme.of(context).colorScheme.primary : null,
                      ),
                      label: Text(dateLabel, style: const TextStyle(fontSize: 12)),
                      onPressed: _selectDateRange,
                    ),
                    if (_startDate != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Limpiar fecha',
                        onPressed: _clearDateRange,
                      ),
                    ],
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: segmented,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 8),
                          dateChip,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    segmented,
                    const SizedBox(width: 12),
                    Expanded(child: searchField),
                    const SizedBox(width: 8),
                    dateChip,
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Listado de Reportes
          Expanded(
            child: switch (vm.viewState) {
              BreakdownReportsViewState.initial ||
              BreakdownReportsViewState.loading =>
                const Center(child: CircularProgressIndicator()),
              BreakdownReportsViewState.error => Center(
                  child: Text('Error: ${vm.errorMessage}'),
                ),
              BreakdownReportsViewState.success => filteredReports.isEmpty
                  ? Center(
                      child: Text(
                        switch (_tab) {
                          _ReportTab.open => 'No hay averías abiertas.',
                          _ReportTab.resolved => 'No hay averías resueltas.',
                          _ReportTab.rejected => 'No hay reportes rechazados.',
                        },
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _loadData(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredReports.length,
                        itemBuilder: (context, index) {
                          final report = filteredReports[index];
                          return _SimpleReportCard(
                            report: report,
                            isProcessing: vm.isProcessing,
                            canGenerateOt: canCreateOt,
                            canResolve: canResolve,
                            canReject: canReject,
                            onGenerateOt: () => _generateWorkOrder(report),
                            onResolve: () => _confirmResolve(report),
                            onReject: () => _confirmReject(report),
                          );
                        },
                      ),
                    ),
            },
          ),
        ],
      ),
    );
  }
}

class _SimpleReportCard extends StatelessWidget {
  const _SimpleReportCard({
    required this.report,
    required this.isProcessing,
    required this.canGenerateOt,
    required this.canResolve,
    required this.canReject,
    required this.onGenerateOt,
    required this.onResolve,
    required this.onReject,
  });

  final BreakdownReport report;
  final bool isProcessing;
  final bool canGenerateOt;
  final bool canResolve;
  final bool canReject;
  final VoidCallback onGenerateOt;
  final VoidCallback onResolve;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final (sevColor, sevBg, sevLabel) = switch (report.severity) {
      BreakdownSeverity.low => (const Color(0xFF15803D), const Color(0xFFDCFCE7), 'Baja'),
      BreakdownSeverity.medium => (const Color(0xFFB45309), const Color(0xFFFEF3C7), 'Media'),
      BreakdownSeverity.high => (const Color(0xFFDC2626), const Color(0xFFFEE2E2), 'Alta'),
    };

    final (statusColor, statusBg, statusLabel) = switch (report.status) {
      BreakdownReportStatus.reported => (null, null, null),
      BreakdownReportStatus.inWorkOrder => (
          const Color(0xFF2563EB),
          const Color(0xFFEFF6FF),
          report.workOrderId != null ? 'En ${report.workOrderId}' : 'En OT',
        ),
      BreakdownReportStatus.resolved => (
          const Color(0xFF16A34A),
          const Color(0xFFDCFCE7),
          'Resuelta',
        ),
      BreakdownReportStatus.rejected => (
          const Color(0xFF64748B),
          const Color(0xFFF1F5F9),
          'Rechazada',
        ),
    };

    final dateStr = report.reportedAt != null
        ? '${report.reportedAt!.day}/${report.reportedAt!.month}/${report.reportedAt!.year} '
            '${report.reportedAt!.hour.toString().padLeft(2, '0')}:'
            '${report.reportedAt!.minute.toString().padLeft(2, '0')}'
        : '—';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera con Wrap para prevenir overflow en móviles
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${report.assetId} — ${report.assetName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '· Área: ${report.areaId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Wrap(
                  spacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: sevBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Sev. $sevLabel',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sevColor),
                      ),
                    ),
                    if (statusLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Descripción
            Text(
              report.description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
            ),

            if (report.status == BreakdownReportStatus.rejected &&
                report.rejectionReason != null) ...[
              const SizedBox(height: 4),
              Text(
                'Motivo rechazo: ${report.rejectionReason}',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],

            const SizedBox(height: 8),

            // Pie: Info de reporte y Botones (con Wrap para móvil)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  'Reportado por: ${report.reportedByUserName}  ·  $dateStr'
                  '${report.workOrderId != null ? " · OT: ${report.workOrderId}" : ""}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (report.status == BreakdownReportStatus.reported) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canGenerateOt)
                        FilledButton(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: isProcessing ? null : onGenerateOt,
                          child: const Text('Generar OT', style: TextStyle(fontSize: 12)),
                        ),
                      if (canReject) ...[
                        const SizedBox(width: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: isProcessing ? null : onReject,
                          child: const Text('Rechazar', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ],
                if (report.status == BreakdownReportStatus.inWorkOrder && canResolve)
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: isProcessing ? null : onResolve,
                    child: const Text('Marcar Resuelta', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectReportDialog extends StatefulWidget {
  const _RejectReportDialog({required this.report});

  final BreakdownReport report;

  @override
  State<_RejectReportDialog> createState() => _RejectReportDialogState();
}

class _RejectReportDialogState extends State<_RejectReportDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar Reporte de Avería'),
      content: SizedBox(
        width: responsiveDialogWidth(context, 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Equipo: ${widget.report.assetId} — ${widget.report.assetName}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                autofocus: true,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motivo de rechazo *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'El motivo es obligatorio.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_reasonController.text.trim());
            }
          },
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}
