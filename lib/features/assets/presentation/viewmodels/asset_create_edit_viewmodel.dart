import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/asset.dart';
import '../../domain/usecases/create_asset_usecase.dart';
import '../../domain/usecases/find_asset_by_serial.dart';
import '../../domain/usecases/get_next_asset_id_usecase.dart';
import '../../domain/usecases/update_asset_usecase.dart';
import '../../../../core/error/failures.dart';

enum AssetFormMode { create, edit }

/// Estado de la verificación en tiempo real del número de serie.
enum SerialCheckState {
  idle,      // El campo está vacío o no aplica
  checking,  // Se está consultando Firestore
  available, // El serial no existe aún: disponible
  conflict,  // El serial ya está registrado → BLOQUEO ESTRICTO
}

class AssetCreateEditViewModel extends ChangeNotifier {
  AssetCreateEditViewModel({
    required CreateAssetUseCase createAssetUseCase,
    required UpdateAssetUseCase updateAssetUseCase,
    required GetNextAssetIdUseCase getNextAssetIdUseCase,
    required FindAssetBySerialUseCase findAssetBySerialUseCase,
  })  : _createAssetUseCase = createAssetUseCase,
        _updateAssetUseCase = updateAssetUseCase,
        _getNextAssetIdUseCase = getNextAssetIdUseCase,
        _findAssetBySerialUseCase = findAssetBySerialUseCase;

  final CreateAssetUseCase _createAssetUseCase;
  final UpdateAssetUseCase _updateAssetUseCase;
  final GetNextAssetIdUseCase _getNextAssetIdUseCase;
  final FindAssetBySerialUseCase _findAssetBySerialUseCase;

  AssetFormMode _mode = AssetFormMode.create;
  AssetFormMode get mode => _mode;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool _success = false;
  bool get success => _success;

  Asset? _lastSaved;
  Asset? get lastSaved => _lastSaved;

  String? _previewId;
  String? get previewId => _previewId;

  // --- Serial check state ---
  SerialCheckState _serialCheckState = SerialCheckState.idle;
  SerialCheckState get serialCheckState => _serialCheckState;

  /// El activo que ya tiene el serial ingresado (cuando hay conflicto).
  Asset? _serialConflictAsset;
  Asset? get serialConflictAsset => _serialConflictAsset;

  Timer? _serialDebounce;

  void initCreate({String? areaId}) {
    _mode = AssetFormMode.create;
    _errorMessage = '';
    _success = false;
    _previewId = null;
    _resetSerialCheck();
    notifyListeners();
  }

  void initEdit(Asset asset) {
    _mode = AssetFormMode.edit;
    _errorMessage = '';
    _success = false;
    _previewId = null;
    _resetSerialCheck();
    notifyListeners();
  }

  void _resetSerialCheck() {
    _serialDebounce?.cancel();
    _serialCheckState = SerialCheckState.idle;
    _serialConflictAsset = null;
  }

  Future<void> loadPreviewId({
    required String areaId,
    String? parentAssetId,
  }) async {
    if (_mode != AssetFormMode.create) return;
    try {
      _previewId = await _getNextAssetIdUseCase(
        GetNextAssetIdParams(
          areaId: areaId,
          parentAssetId: parentAssetId,
        ),
      );
    } catch (_) {
      _previewId = null;
    }
    notifyListeners();
  }

  /// Verifica en tiempo real si el [serial] ingresado ya existe globalmente.
  ///
  /// Aplica un debounce de 600ms para evitar consultas excesivas a Firestore.
  /// Si el serial ya pertenece a otro activo, el registro queda BLOQUEADO.
  void checkSerial(String serial) {
    _serialDebounce?.cancel();

    if (serial.trim().isEmpty) {
      _serialCheckState = SerialCheckState.idle;
      _serialConflictAsset = null;
      notifyListeners();
      return;
    }

    _serialCheckState = SerialCheckState.checking;
    notifyListeners();

    _serialDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final existing = await _findAssetBySerialUseCase(
          FindAssetBySerialParams(serial),
        );
        if (existing != null) {
          _serialCheckState = SerialCheckState.conflict;
          _serialConflictAsset = existing;
        } else {
          _serialCheckState = SerialCheckState.available;
          _serialConflictAsset = null;
        }
      } catch (_) {
        _serialCheckState = SerialCheckState.idle;
        _serialConflictAsset = null;
      }
      notifyListeners();
    });
  }

  Future<bool> save({
    required String id,
    required String name,
    String? brand,
    String? model,
    required String areaId,
    required String stationId,
    String? parentAssetId,
    required AssetLevel level,
    required List<String> ancestors,
    AssetStatus status = AssetStatus.active,
    Map<String, dynamic>? dynamicAttributes,
    String? imageData,
    String? serial,
    required String userId,
    required String userName,
  }) async {
    // Si hay un conflicto detectado en tiempo real, bloquea el guardado inmediatamente.
    if (_serialCheckState == SerialCheckState.conflict && _serialConflictAsset != null) {
      _errorMessage =
          'No se puede registrar: el número de serie ya pertenece al activo ${_serialConflictAsset!.id} (${_serialConflictAsset!.name}).';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final asset = Asset(
        id: id,
        name: name.trim(),
        brand: brand?.trim().isEmpty == true ? null : brand?.trim(),
        model: model?.trim().isEmpty == true ? null : model?.trim(),
        areaId: areaId.trim(),
        stationId: stationId.trim(),
        parentAssetId:
            parentAssetId?.trim().isEmpty == true ? null : parentAssetId?.trim(),
        level: level,
        ancestors: ancestors,
        status: status,
        dynamicAttributes: dynamicAttributes ?? {},
        imageData: imageData,
        serial: serial?.trim().isEmpty == true ? null : serial?.trim(),
      );

      if (_mode == AssetFormMode.create) {
        await _createAssetUseCase(
          CreateAssetParams(asset, userId: userId, userName: userName),
        );
      } else {
        await _updateAssetUseCase(
          UpdateAssetParams(asset, userId: userId, userName: userName),
        );
      }

      _lastSaved = asset;
      _success = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on SerialConflictFailure catch (e) {
      _serialCheckState = SerialCheckState.conflict;
      _serialConflictAsset = e.conflictingAsset;
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _serialDebounce?.cancel();
    super.dispose();
  }
}
