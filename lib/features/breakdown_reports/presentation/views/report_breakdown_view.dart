import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../domain/entities/breakdown_report.dart';
import '../viewmodels/report_breakdown_viewmodel.dart';

class ReportBreakdownView extends StatefulWidget {
  const ReportBreakdownView({super.key});

  @override
  State<ReportBreakdownView> createState() => _ReportBreakdownViewState();
}

class _ReportBreakdownViewState extends State<ReportBreakdownView> {
  late final ReportBreakdownViewModel _viewModel =
      getIt<ReportBreakdownViewModel>();

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Avería reportada. Quedó registrado en el kardex.'
              : _viewModel.errorMessage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReportBreakdownViewModel>.value(
      value: _viewModel,
      child: _ReportForm(onSubmit: _submit),
    );
  }
}

class _ReportForm extends StatelessWidget {
  const _ReportForm({required this.onSubmit});

  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportBreakdownViewModel>();

    return Material(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reportar Avería',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'Selecciona el área, el activo afectado y describe la avería. '
                    'El reporte quedará a disposición del gestor del sistema.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Área
          DropdownButtonFormField<String>(
            key: const Key('breakdown-area'),
            initialValue: vm.selectedAreaId,
            decoration: const InputDecoration(
              labelText: 'Área *',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final area in vm.areas)
                DropdownMenuItem(
                  value: area.id,
                  child: Text('${area.id} — ${area.name}'),
                ),
            ],
            onChanged: vm.isLoadingAreas
                ? null
                : (value) {
                    if (value != null) vm.selectArea(value);
                  },
          ),
          const SizedBox(height: 12),

          // Activo de la área seleccionada
          if (vm.selectedAreaId != null) ...[
            if (vm.isLoadingAssets)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (vm.assets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'El área no tiene activos registrados.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              DropdownButtonFormField<String>(
                key: ValueKey('breakdown-asset-${vm.selectedAreaId}'),
                initialValue: vm.selectedAssetId,
                decoration: const InputDecoration(
                  labelText: 'Activo *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final Asset asset in vm.assets)
                    DropdownMenuItem(
                      value: asset.id,
                      child: Text(
                        '${asset.id} — ${asset.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => vm.selectAsset(value),
              ),
            const SizedBox(height: 12),
          ],

          // Descripción
          TextField(
            key: const Key('breakdown-description'),
            maxLines: 4,
            minLines: 3,
            onChanged: vm.setDescription,
            decoration: const InputDecoration(
              labelText: 'Descripción de la avería *',
              hintText: 'Ej.: fugas de aceite en el sello, ruido excesivo...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Severidad
          Text('Severidad', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<BreakdownSeverity>(
            segments: const [
              ButtonSegment(
                value: BreakdownSeverity.low,
                label: Text('Baja'),
                icon: Icon(Icons.arrow_downward),
              ),
              ButtonSegment(
                value: BreakdownSeverity.medium,
                label: Text('Media'),
                icon: Icon(Icons.remove),
              ),
              ButtonSegment(
                value: BreakdownSeverity.high,
                label: Text('Alta'),
                icon: Icon(Icons.arrow_upward),
              ),
            ],
            selected: {vm.severity},
            onSelectionChanged: (selection) =>
                vm.setSeverity(selection.first),
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            key: const Key('breakdown-submit'),
            onPressed: vm.isSubmitting ? null : onSubmit,
            icon: vm.isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Enviar reporte'),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
