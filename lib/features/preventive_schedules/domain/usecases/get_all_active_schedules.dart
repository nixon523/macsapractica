import '../../../../core/usecases/usecase.dart';
import '../entities/preventive_schedule.dart';
import '../repositories/preventive_schedule_repository.dart';

class GetAllActiveSchedulesParams {
  const GetAllActiveSchedulesParams({
    this.startDate,
    this.endDate,
  });

  final DateTime? startDate;
  final DateTime? endDate;
}

class GetAllActiveSchedulesUseCase
    implements UseCase<List<PreventiveSchedule>, GetAllActiveSchedulesParams> {
  const GetAllActiveSchedulesUseCase(this._repository);

  final PreventiveScheduleRepository _repository;

  @override
  Future<List<PreventiveSchedule>> call([
    GetAllActiveSchedulesParams params = const GetAllActiveSchedulesParams(),
  ]) {
    return _repository.getAllSchedules(
      status: ScheduleStatus.active,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}
