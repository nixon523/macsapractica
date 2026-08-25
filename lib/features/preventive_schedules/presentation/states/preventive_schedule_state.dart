import '../../domain/entities/preventive_schedule.dart';

enum ViewState { initial, loading, success, error }

class PreventiveScheduleState {
  const PreventiveScheduleState({
    this.viewState = ViewState.initial,
    this.schedules = const [],
    this.errorMessage = '',
  });

  final ViewState viewState;
  final List<PreventiveSchedule> schedules;
  final String errorMessage;

  bool get isLoading => viewState == ViewState.loading;
  bool get isError => viewState == ViewState.error;
  bool get isSuccess => viewState == ViewState.success;
}
