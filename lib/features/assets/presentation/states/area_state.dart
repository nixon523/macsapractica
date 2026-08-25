import '../../domain/entities/area.dart';

enum ViewState { initial, loading, success, error }

/// Estado inmutable expuesto por el ViewModel a la View.
class AreaState {
  const AreaState({
    this.viewState = ViewState.initial,
    this.areas = const [],
    this.errorMessage = '',
  });

  final ViewState viewState;
  final List<Area> areas;
  final String errorMessage;

  AreaState copyWith({
    ViewState? viewState,
    List<Area>? areas,
    String? errorMessage,
  }) {
    return AreaState(
      viewState: viewState ?? this.viewState,
      areas: areas ?? this.areas,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isLoading => viewState == ViewState.loading;
  bool get isError => viewState == ViewState.error;
  bool get isSuccess => viewState == ViewState.success;
}
