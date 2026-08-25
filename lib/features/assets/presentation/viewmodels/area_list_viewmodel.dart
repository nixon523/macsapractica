import 'package:flutter/foundation.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/get_areas_usecase.dart';
import '../../domain/usecases/update_area_usecase.dart';
import '../states/area_state.dart';

class AreaListViewModel extends ChangeNotifier {
  AreaListViewModel({
    required this.getAreasUseCase,
    this.updateAreaUseCase,
  });

  final GetAreasUseCase getAreasUseCase;
  final UpdateAreaUseCase? updateAreaUseCase;

  AreaState _state = const AreaState();
  AreaState get state => _state;

  Future<void> fetchAreas({bool forceRefresh = false}) async {
    _state = _state.copyWith(
      viewState: ViewState.loading,
      errorMessage: '',
    );
    notifyListeners();

    try {
      final areas = await getAreasUseCase(const NoParams());
      _state = _state.copyWith(
        viewState: ViewState.success,
        areas: areas,
      );
    } catch (e) {
      _state = _state.copyWith(
        viewState: ViewState.error,
        errorMessage: e.toString(),
      );
    } finally {
      notifyListeners();
    }
  }

  Future<bool> updateAreaName(String id, String newName) async {
    if (updateAreaUseCase == null) return false;
    try {
      await updateAreaUseCase!(
        UpdateAreaParams(id: id, name: newName),
      );
      await fetchAreas(forceRefresh: true);
      return true;
    } catch (e) {
      _state = _state.copyWith(errorMessage: e.toString());
      notifyListeners();
      return false;
    }
  }
}
