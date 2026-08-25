import '../../domain/entities/asset.dart';

enum ViewState { initial, loading, success, error }

/// Estado inmutable expuesto por el ViewModel a la View.
class AssetState {
  const AssetState({
    this.viewState = ViewState.initial,
    this.assets = const [],
    this.errorMessage = '',
    this.selectedAsset,
    this.isSearching = false,
    this.statusFilter,
  });

  final ViewState viewState;
  final List<Asset> assets;
  final String errorMessage;
  final Asset? selectedAsset;
  final bool isSearching;
  final AssetStatus? statusFilter;

  AssetState copyWith({
    ViewState? viewState,
    List<Asset>? assets,
    String? errorMessage,
    Asset? selectedAsset,
    bool? isSearching,
    AssetStatus? statusFilter,
  }) {
    return AssetState(
      viewState: viewState ?? this.viewState,
      assets: assets ?? this.assets,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedAsset: selectedAsset ?? this.selectedAsset,
      isSearching: isSearching ?? this.isSearching,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }

  bool get isLoading => viewState == ViewState.loading;
  bool get isError => viewState == ViewState.error;
  bool get isSuccess => viewState == ViewState.success;
}
