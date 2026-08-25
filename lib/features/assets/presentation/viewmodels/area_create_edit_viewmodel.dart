import 'package:flutter/foundation.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/create_area_usecase.dart';
import '../../domain/usecases/get_next_area_id_usecase.dart';

class AreaCreateEditViewModel extends ChangeNotifier {
  AreaCreateEditViewModel({
    required this.createAreaUseCase,
    required this.getNextAreaIdUseCase,
  });

  final CreateAreaUseCase createAreaUseCase;
  final GetNextAreaIdUseCase getNextAreaIdUseCase;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String? _previewId;
  String? get previewId => _previewId;

  Future<void> loadPreviewId() async {
    try {
      _previewId = await getNextAreaIdUseCase(const NoParams());
    } catch (_) {
      _previewId = null;
    }
    notifyListeners();
  }

  Future<bool> save({
    required String name,
    required String costCenter,
    String? customId,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final area = await createAreaUseCase(
        CreateAreaParams(
          name: name,
          costCenter: costCenter,
          customId: customId,
        ),
      );
      _previewId = area.id;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
