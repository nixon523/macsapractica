import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:macsapractica/app/di/get_it.dart';
import '../../domain/entities/cost_center_catalog.dart';
import '../viewmodels/area_create_edit_viewmodel.dart';

class AreaCreateView extends StatelessWidget {
  const AreaCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AreaCreateEditViewModel>(
      create: (_) => getIt<AreaCreateEditViewModel>(),
      child: const _AreaForm(),
    );
  }
}

class _AreaForm extends StatefulWidget {
  const _AreaForm();

  @override
  State<_AreaForm> createState() => _AreaFormState();
}

class _AreaFormState extends State<_AreaForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _costCenterCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _costCenterCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AreaCreateEditViewModel>().loadPreviewId();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _costCenterCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<AreaCreateEditViewModel>();
    final ok = await vm.save(
      name: _nameCtrl.text,
      costCenter: _costCenterCtrl.text,
    );

    if (ok && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AreaCreateEditViewModel>();
    final currentPreview = vm.previewId ?? '...';

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Área / Centro de Costo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de Área / Centro de Costo *',
                  hintText: 'Ej: ALMACEN GENERAL',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costCenterCtrl,
                decoration: const InputDecoration(
                  labelText: 'ID Centro de costo *',
                  hintText: 'Ej: CC-99',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: ValueKey(currentPreview),
                initialValue: currentPreview,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Código de área (ID)',
                  helperText: 'Se asigna automáticamente de forma secuencial.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              if (vm.errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    vm.errorMessage,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              FilledButton(
                onPressed: vm.isLoading ? null : _onSave,
                child: vm.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear Área'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
