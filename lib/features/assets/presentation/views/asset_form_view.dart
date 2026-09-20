import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../../app/widgets/app_form_shell.dart';
import '../../data/datasources/asset_remote_datasource.dart';
import '../../domain/entities/asset.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../viewmodels/asset_create_edit_viewmodel.dart';
import 'widgets/asset_image_widget.dart';

const _levelLabels = {
  AssetLevel.equipment: 'Equipo',
  AssetLevel.subEquipment: 'Sub-equipo',
  AssetLevel.part: 'Parte',
  AssetLevel.subPart: 'Sub-parte',
};

const _statusLabels = {
  AssetStatus.active: 'Activo',
  AssetStatus.inactive: 'Inactivo',
  AssetStatus.transferredDeactivated: 'Transferido / Desactivado',
};

const _maxImageDimension = 1200;
const _jpegQuality = 80;

/// Redimensiona y optimiza la imagen antes de subirla al servidor.
Future<Uint8List> _compressImageBytes(Uint8List bytes) async {
  img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('No se pudo leer la imagen seleccionada.');
  }
  if (decoded.width > _maxImageDimension || decoded.height > _maxImageDimension) {
    decoded = img.copyResize(
      decoded,
      width: _maxImageDimension,
      maintainAspect: true,
      interpolation: img.Interpolation.cubic,
    );
  }
  return Uint8List.fromList(img.encodeJpg(decoded, quality: _jpegQuality));
}

AssetLevel _nextLevel(AssetLevel level) {
  return switch (level) {
    AssetLevel.equipment => AssetLevel.subEquipment,
    AssetLevel.subEquipment => AssetLevel.part,
    AssetLevel.part => AssetLevel.subPart,
    AssetLevel.subPart => AssetLevel.subPart,
  };
}

class AssetFormView extends StatefulWidget {
  const AssetFormView({
    super.key,
    this.asset,
    required this.areaId,
    this.parentAsset,
  });

  final Asset? asset;
  final String areaId;
  final Asset? parentAsset;

  @override
  State<AssetFormView> createState() => _AssetFormViewState();
}

class _AssetFormViewState extends State<AssetFormView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;

  late final TextEditingController _serialCtrl;
  late final TextEditingController _newAttrKeyCtrl;
  late final TextEditingController _newAttrValueCtrl;

  late String _areaId;
  late AssetLevel _level;
  late AssetStatus _status;
  String? _parentAssetId;
  late Map<String, dynamic> _dynamicAttributes;
  String? _imageData;
  Uint8List? _pendingImageBytes;
  String? _pendingImageFilename;
  bool _imageProcessing = false;

  bool get _isEditing => widget.asset != null;

  String get _levelLabel => _levelLabels[_level] ?? _level.name;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    final parent = widget.parentAsset;
    _nameCtrl = TextEditingController(text: asset?.name ?? '');
    _brandCtrl = TextEditingController(text: asset?.brand ?? '');
    _modelCtrl = TextEditingController(text: asset?.model ?? '');

    _serialCtrl = TextEditingController(text: asset?.serial ?? '');
    _newAttrKeyCtrl = TextEditingController();
    _newAttrValueCtrl = TextEditingController();
    _areaId = asset?.areaId ?? widget.areaId;
    _parentAssetId = asset?.parentAssetId ?? parent?.id;
    _level = _isEditing
        ? asset!.level
        : parent != null
            ? _nextLevel(parent.level)
            : AssetLevel.equipment;
    _status = _isEditing ? asset!.status : AssetStatus.active;
    _dynamicAttributes = Map<String, dynamic>.from(
      asset?.dynamicAttributes ?? {},
    );
    _imageData = asset?.imageData;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<AssetCreateEditViewModel>();
      if (_isEditing) {
        vm.initEdit(asset!);
      } else {
        vm.initCreate(areaId: widget.areaId);
        vm.loadPreviewId(
          areaId: widget.areaId,
          parentAssetId: _parentAssetId,
        );
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();

    _serialCtrl.dispose();
    _newAttrKeyCtrl.dispose();
    _newAttrValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<AssetCreateEditViewModel>();
    final asset = widget.asset;
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    // Si se seleccionó una imagen nueva, subirla a la API antes de guardar
    if (_pendingImageBytes != null) {
      setState(() => _imageProcessing = true);
      try {
        final datasource = getIt<AssetRemoteDataSource>();
        final uploadedUrl = await datasource.uploadAssetImage(
          _pendingImageBytes!,
          filename: _pendingImageFilename ?? 'asset.jpg',
        );
        _imageData = uploadedUrl;
        _pendingImageBytes = null;
      } catch (e) {
        if (mounted) {
          setState(() => _imageProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir la imagen al servidor: $e')),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _imageProcessing = false);
      }
    }

    final ok = await vm.save(
      id: asset?.id ?? '',
      name: _nameCtrl.text,
      brand: _brandCtrl.text,
      model: _modelCtrl.text,
      areaId: _areaId,
      stationId: '',
      parentAssetId: _parentAssetId,
      level: _level,
      ancestors: asset?.ancestors ?? const [],
      status: _status,
      dynamicAttributes: _dynamicAttributes,
      imageData: _imageData,
      serial: _level == AssetLevel.equipment ? _serialCtrl.text : null,
      userId: user.userId,
      userName: user.username,
    );

    if (ok && mounted) {
      Navigator.of(context).pop(vm.lastSaved);
    }
  }

  void _addAttribute() {
    final key = _newAttrKeyCtrl.text.trim();
    final value = _newAttrValueCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _dynamicAttributes[key] = value;
      _newAttrKeyCtrl.clear();
      _newAttrValueCtrl.clear();
    });
  }

  void _removeAttribute(String key) {
    setState(() {
      _dynamicAttributes.remove(key);
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxImageDimension.toDouble(),
      maxHeight: _maxImageDimension.toDouble(),
    );
    if (file == null) return;

    setState(() => _imageProcessing = true);
    try {
      final rawBytes = await file.readAsBytes();
      final compressedBytes = await _compressImageBytes(rawBytes);
      if (!mounted) return;
      setState(() {
        _pendingImageBytes = compressedBytes;
        _pendingImageFilename = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar la imagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _imageProcessing = false);
    }
  }

  void _removeImage() {
    setState(() {
      _imageData = null;
      _pendingImageBytes = null;
      _pendingImageFilename = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssetCreateEditViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Activo' : 'Crear Activo'),
      ),
      body: SingleChildScrollView(
        child: AppFormShell(
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: _isEditing
                    ? widget.asset!.id
                    : (vm.previewId ?? 'Generando...'),
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'ID del activo',
                  helperText: _isEditing
                      ? 'El ID no se puede modificar.'
                      : 'Se asigna automáticamente según el área y el padre.',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  hintText: 'Ej: MotorPrincipal-A1',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _brandCtrl,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  hintText: 'Ej: Siemens',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  hintText: 'Ej: SIMATIC S7-1200',
                  border: OutlineInputBorder(),
                ),
              ),
              // --- Campo Serial (solo equipos raíz) ---
              if (_level == AssetLevel.equipment) ...[
                const SizedBox(height: 16),
                _SerialField(
                  controller: _serialCtrl,
                  isEditing: _isEditing,
                  checkState: vm.serialCheckState,
                  conflictAsset: vm.serialConflictAsset,
                  onChanged: _isEditing
                      ? null // El serial es inmutable: no se puede editar
                      : (value) => vm.checkSerial(value),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _levelLabel,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Nivel',
                  helperText: 'Se deriva de la jerarquía del activo padre.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AssetStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                ),
                items: [
                  // Solo los estados mantenibles manualmente: `active`/`inactive`.
                  // `deleted` solo lo asigna el gerente al aprobar una baja y
                  // `transferredDeactivated` es un estado de sistema (el detalle
                  // oculta la edición para esos activos).
                  for (final status in AssetStatus.values)
                    if (status == AssetStatus.active ||
                        status == AssetStatus.inactive)
                      DropdownMenuItem(
                        value: status,
                        child: Text(_statusLabels[status] ?? status.name),
                      ),
                ],
                onChanged: (status) {
                  if (status != null) {
                    setState(() => _status = status);
                  }
                },
              ),
              if (_parentAssetId != null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _parentAssetId,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Activo padre',
                    helperText: 'Este activo pertenece a la jerarquía de:',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _ImageSection(
                imageData: _imageData,
                pendingBytes: _pendingImageBytes,
                processing: _imageProcessing,
                onPick: _pickImage,
                onRemove: _removeImage,
              ),
              const SizedBox(height: 8),
              Text(
                'Atributos dinámicos',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (_dynamicAttributes.isNotEmpty) ...[
                for (final entry in _dynamicAttributes.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${entry.key}: ${entry.value}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _removeAttribute(entry.key),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newAttrKeyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Clave',
                        hintText: 'Ej: potencia',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _newAttrValueCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        hintText: 'Ej: 150kW',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _addAttribute,
                  ),
                ],
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
                onPressed: (vm.isLoading || vm.serialCheckState == SerialCheckState.conflict)
                    ? null
                    : _onSave,
                child: vm.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Guardar Cambios' : 'Crear Activo'),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.imageData,
    required this.pendingBytes,
    required this.processing,
    required this.onPick,
    required this.onRemove,
  });

  final String? imageData;
  final Uint8List? pendingBytes;
  final bool processing;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imagen del activo',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (processing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (pendingBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              pendingBytes!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Cambiar imagen'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Quitar'),
              ),
            ],
          ),
        ] else if (imageData != null && imageData!.trim().isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AssetImageWidget(
              imageData: imageData,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Cambiar imagen'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Quitar'),
              ),
            ],
          ),
        ] else
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Seleccionar imagen'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'La imagen se almacena en el servidor y se asocia al activo de forma optimizada.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Campo de número de serie con verificación en tiempo real.
///
/// Muestra debajo del campo el estado de la consulta:
/// - Spinner   → consultando Firestore
/// - ✅ Verde  → serial disponible
/// - ⛔ Rojo   → BLOQUEADO: muestra ID, nombre y área del activo conflictivo
/// En modo edición el campo es de solo lectura (el serial es inmutable).
class _SerialField extends StatelessWidget {
  const _SerialField({
    required this.controller,
    required this.isEditing,
    required this.checkState,
    required this.conflictAsset,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isEditing;
  final SerialCheckState checkState;
  final Asset? conflictAsset;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget? suffixIcon;
    if (!isEditing) {
      suffixIcon = switch (checkState) {
        SerialCheckState.checking => const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        SerialCheckState.available =>
          Icon(Icons.check_circle_outline, color: colors.primary, size: 22),
        SerialCheckState.conflict =>
          Icon(Icons.block, color: colors.error, size: 22),
        SerialCheckState.idle => null,
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          readOnly: isEditing,
          enabled: !isEditing,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: isEditing ? 'N° de Serie' : 'N° de Serie (opcional)',
            hintText: isEditing ? null : 'Ej: SN-2023-00142',
            helperText: isEditing
                ? 'El número de serie no puede modificarse.'
                : 'Tal como aparece en la placa física del equipo.',
            border: const OutlineInputBorder(),
            suffixIcon: suffixIcon,
          ),
        ),
        if (!isEditing) ...[
          const SizedBox(height: 6),
          if (checkState == SerialCheckState.available)
            Row(
              children: [
                const SizedBox(width: 4),
                Icon(Icons.check_circle, color: colors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Serial disponible',
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.primary),
                ),
              ],
            ),
          if (checkState == SerialCheckState.conflict && conflictAsset != null) ...[
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.error),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.block, color: colors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⛔ Número de serie no disponible',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Este serial ya pertenece al equipo:',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onErrorContainer),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${conflictAsset!.id} — ${conflictAsset!.name}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onErrorContainer,
                    ),
                  ),
                  Text(
                    'Área actual: ${conflictAsset!.areaId}'
                    '${conflictAsset!.status != AssetStatus.active ? " (${conflictAsset!.status.name})" : ""}',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onErrorContainer),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Para mantener la integridad del inventario de Grupo MACSA, no se permite registrar equipos con números de serie duplicados.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: colors.onErrorContainer.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

