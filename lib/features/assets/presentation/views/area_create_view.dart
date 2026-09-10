import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/upper_case_formatter.dart';
import 'package:macsapractica/app/di/get_it.dart';
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
    final formattedName = _nameCtrl.text.trim().toUpperCase();
    final formattedCC = _costCenterCtrl.text.trim().toUpperCase();

    final ok = await vm.save(
      name: formattedName,
      costCenter: formattedCC,
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Área "$formattedName" creada exitosamente.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final vm = context.watch<AreaCreateEditViewModel>();
    final currentPreview = vm.previewId ?? 'A...';

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Nueva Área / Centro de Costo'),
        centerTitle: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
                ),
                color: colors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Encabezado con Icono Ejecutivo
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.domain_add_rounded,
                                size: 28,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Registro de Área Operativa',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Define una nueva ubicación o planta para organizar activos, mantenimientos y órdenes de trabajo.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: colors.onSurfaceVariant,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Tarjeta de Código Asignado Automáticamente
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tag, size: 20, color: Color(0xFF0284C7)),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Código de Área (ID Secuencial)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentPreview,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0369A1),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Automático',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Campo 1: Nombre de Área
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [UpperCaseTextFormatter()],
                          decoration: InputDecoration(
                            labelText: 'Nombre del Área o Planta *',
                            hintText: 'Ej: PLANTA DE ENVASADO, CALDERAS, RECEPCIÓN',
                            prefixIcon: const Icon(Icons.business_outlined, size: 20),
                            filled: true,
                            fillColor: colors.surfaceContainerLowest,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'El nombre del área es obligatorio.';
                            }
                            if (v.trim().length < 3) {
                              return 'El nombre debe tener al menos 3 caracteres.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Campo 2: Centro de Costo
                        TextFormField(
                          controller: _costCenterCtrl,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [UpperCaseTextFormatter()],
                          decoration: InputDecoration(
                            labelText: 'Centro de Costo (CC) *',
                            hintText: 'Ej: CC-50 o 50',
                            prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                            helperText: 'Se formateará automáticamente como CC-XX.',
                            filled: true,
                            fillColor: colors.surfaceContainerLowest,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'El centro de costo es obligatorio.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        if (vm.errorMessage.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFF87171)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 20, color: Color(0xFFDC2626)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    vm.errorMessage,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Botones de Acción
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: vm.isLoading ? null : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: vm.isLoading ? null : _onSave,
                                icon: vm.isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check, size: 18),
                                label: Text(vm.isLoading ? 'Guardando...' : 'Crear Área'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
