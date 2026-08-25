import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/asset_delete_request.dart';
import '../viewmodels/deletion_requests_viewmodel.dart';

class DeletionRequestsView extends StatefulWidget {
  const DeletionRequestsView({super.key});

  @override
  State<DeletionRequestsView> createState() => _DeletionRequestsViewState();
}

class _DeletionRequestsViewState extends State<DeletionRequestsView> {
  late final DeletionRequestsViewModel _viewModel =
      getIt<DeletionRequestsViewModel>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewModel.load();
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DeletionRequestsViewModel>.value(
      value: _viewModel,
      child: const _DeletionRequestsContent(),
    );
  }
}

class _DeletionRequestsContent extends StatefulWidget {
  const _DeletionRequestsContent();

  @override
  State<_DeletionRequestsContent> createState() =>
      _DeletionRequestsContentState();
}

class _DeletionRequestsContentState extends State<_DeletionRequestsContent> {
  bool _showResolved = false;
  DateTime? _startDate;
  DateTime? _endDate;

  void _loadData() {
    context.read<DeletionRequestsViewModel>().load(
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

  Future<void> _confirmApprove(AssetDeleteRequest request) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar eliminación'),
        content: Text(
          'Se dará de baja ${request.assetId} (${request.assetName}) junto '
          'con su subárbol (${request.subtreeCount} activo(s)). '
          'Quedará registrado en el kardex. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final viewModel = context.read<DeletionRequestsViewModel>();
    final ok = await viewModel.approve(
      request: request,
      approvedByUserId: user.userId,
      approvedByUserName: user.username,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Solicitud aprobada: ${request.assetId} dado de baja.'
              : 'Error: ${viewModel.errorMessage}',
        ),
      ),
    );
  }

  Future<void> _confirmReject(AssetDeleteRequest request) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: reasonCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo del rechazo *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes indicar el motivo del rechazo.')),
      );
      return;
    }

    final viewModel = context.read<DeletionRequestsViewModel>();
    final ok = await viewModel.reject(
      request: request,
      rejectedByUserId: user.userId,
      rejectedByUserName: user.username,
      rejectReason: reason,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Solicitud rechazada.' : 'Error: ${viewModel.errorMessage}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeletionRequestsViewModel>();

    final dateLabel = _startDate == null
        ? 'Filtrar fecha'
        : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Pendientes'),
                    icon: Icon(Icons.pending_actions),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Resueltas'),
                    icon: Icon(Icons.history),
                  ),
                ],
                selected: {_showResolved},
                onSelectionChanged: (selection) {
                  setState(() => _showResolved = selection.first);
                },
              ),
              ActionChip(
                avatar: Icon(
                  Icons.date_range,
                  size: 18,
                  color: _startDate != null ? Colors.blue : null,
                ),
                label: Text(dateLabel),
                onPressed: _selectDateRange,
              ),
              if (_startDate != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: 'Limpiar fecha',
                  onPressed: _clearDateRange,
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (vm.viewState) {
            DeletionRequestsViewState.loading => const Center(
                child: CircularProgressIndicator(),
              ),
            DeletionRequestsViewState.error => Center(
                child: Text('Error: ${vm.errorMessage}'),
              ),
            DeletionRequestsViewState.initial ||
            DeletionRequestsViewState.success =>
              _RequestsList(
                requests: _showResolved
                    ? vm.resolvedRequests
                    : vm.pendingRequests,
                showResolved: _showResolved,
                isProcessing: vm.isProcessing,
                onRefresh: () async => _loadData(),
                onApprove: _confirmApprove,
                onReject: _confirmReject,
              ),
          },
        ),
      ],
    );
  }
}

class _RequestsList extends StatelessWidget {
  const _RequestsList({
    required this.requests,
    required this.showResolved,
    required this.isProcessing,
    required this.onRefresh,
    required this.onApprove,
    required this.onReject,
  });

  final List<AssetDeleteRequest> requests;
  final bool showResolved;
  final bool isProcessing;
  final Future<void> Function() onRefresh;
  final ValueChanged<AssetDeleteRequest> onApprove;
  final ValueChanged<AssetDeleteRequest> onReject;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Text(
          showResolved
              ? 'Aún no hay solicitudes resueltas.'
              : 'No hay solicitudes pendientes.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${request.assetId} - ${request.assetName}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (showResolved)
                        _ResolutionChip(status: request.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Área: ${request.areaId}'),
                  Text('Solicitado por: ${request.requestedByUserName}'),
                  Text('Subárbol: ${request.subtreeCount} activo(s)'),
                  Text('Motivo: ${request.reason}'),
                  if (request.decisionReason != null &&
                      request.decisionReason!.isNotEmpty)
                    Text('Decisión: ${request.decisionReason}'),
                  if (request.decidedByUserName != null)
                    Text('Resuelto por: ${request.decidedByUserName}'),
                  if (showResolved && request.requestedAt != null)
                    Text(
                      'Solicitado: ${_format(request.requestedAt)} · '
                      'Resuelto: ${_format(request.decidedAt)}',
                    ),
                  if (!showResolved) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed:
                              isProcessing ? null : () => onReject(request),
                          icon: const Icon(Icons.close),
                          label: const Text('Rechazar'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton.icon(
                          onPressed:
                              isProcessing ? null : () => onApprove(request),
                          icon: const Icon(Icons.check),
                          label: const Text('Aprobar'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _format(DateTime? date) {
    if (date == null) return '—';
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ResolutionChip extends StatelessWidget {
  const _ResolutionChip({required this.status});

  final DeletionRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      DeletionRequestStatus.approved => Colors.green,
      DeletionRequestStatus.rejected => Colors.red,
      DeletionRequestStatus.pending => Colors.orange,
    };
    final label = switch (status) {
      DeletionRequestStatus.approved => 'Aprobada',
      DeletionRequestStatus.rejected => 'Rechazada',
      DeletionRequestStatus.pending => 'Pendiente',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
