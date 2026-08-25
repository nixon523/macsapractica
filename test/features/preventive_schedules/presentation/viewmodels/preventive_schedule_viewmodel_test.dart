import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/preventive_schedules/domain/entities/preventive_schedule.dart';
import 'package:macsapractica/features/preventive_schedules/domain/repositories/preventive_schedule_repository.dart';
import 'package:macsapractica/features/preventive_schedules/presentation/viewmodels/preventive_schedule_viewmodel.dart';
import 'package:mocktail/mocktail.dart';

class MockPreventiveScheduleRepository extends Mock
    implements PreventiveScheduleRepository {}

void main() {
  late MockPreventiveScheduleRepository mockRepo;
  late PreventiveScheduleViewModel viewModel;

  setUpAll(() {
    registerFallbackValue(ScheduleStatus.active);
    registerFallbackValue(
      PreventiveSchedule(
        id: 'PM-001',
        assetId: 'EQ-01',
        areaId: 'A1',
        maintenanceType: 'Mecánico',
        frequency: ScheduleFrequency.monthly,
        startDate: DateTime.now(),
        nextDate: DateTime.now().add(const Duration(days: 30)),
        status: ScheduleStatus.active,
      ),
    );
  });

  setUp(() {
    mockRepo = MockPreventiveScheduleRepository();
    viewModel = PreventiveScheduleViewModel(repository: mockRepo);
  });

  test('loadSchedules carga la lista y actualiza el contador de urgentes', () async {
    final now = DateTime.now();
    final sampleList = [
      PreventiveSchedule(
        id: 'PM-001',
        assetId: 'EQ-01',
        areaId: 'A1',
        maintenanceType: 'Mecánico',
        frequency: ScheduleFrequency.monthly,
        startDate: now,
        nextDate: now.subtract(const Duration(days: 1)), // Vencido
        status: ScheduleStatus.active,
      ),
      PreventiveSchedule(
        id: 'PM-002',
        assetId: 'EQ-02',
        areaId: 'A1',
        maintenanceType: 'Eléctrico',
        frequency: ScheduleFrequency.monthly,
        startDate: now,
        nextDate: now.add(const Duration(days: 1)), // Urgente
        status: ScheduleStatus.active,
      ),
      PreventiveSchedule(
        id: 'PM-003',
        assetId: 'EQ-03',
        areaId: 'A1',
        maintenanceType: 'Lubricación',
        frequency: ScheduleFrequency.monthly,
        startDate: now,
        nextDate: now.add(const Duration(days: 20)), // Al día
        status: ScheduleStatus.active,
      ),
    ];

    when(() => mockRepo.getAllSchedules(
          areaId: any(named: 'areaId'),
          status: any(named: 'status'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer((_) async => sampleList);

    await viewModel.loadSchedules();

    expect(viewModel.state.schedules.length, 3);
    expect(viewModel.urgentAndOverdueCount, 2); // 1 vencido + 1 urgente
  });

  test('createSchedule delega en el repositorio y recarga el listado', () async {
    final now = DateTime.now();
    final newSchedule = PreventiveSchedule(
      id: 'PM-2026-0001',
      title: 'Plan Compresor',
      assetId: 'EQ-01',
      areaId: 'A1',
      maintenanceType: 'Mecánico',
      frequency: ScheduleFrequency.monthly,
      startDate: now,
      nextDate: now.add(const Duration(days: 30)),
      status: ScheduleStatus.active,
    );

    when(() => mockRepo.createSchedule(
          schedule: any(named: 'schedule'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
        )).thenAnswer((_) async => newSchedule);

    when(() => mockRepo.getAllSchedules(
          areaId: any(named: 'areaId'),
          status: any(named: 'status'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer((_) async => [newSchedule]);

    final ok = await viewModel.createSchedule(
      schedule: newSchedule,
      userId: 'admin',
      userName: 'Gestor del Sistema',
    );

    expect(ok, isTrue);
    expect(viewModel.state.schedules.length, 1);
    expect(viewModel.successMessage, contains('PM-2026-0001'));
  });

  test('amendSchedule aplica la modificación con autorización gerencial', () async {
    final now = DateTime.now();
    final updated = PreventiveSchedule(
      id: 'PM-2026-0001',
      title: 'Plan Compresor Modificado',
      assetId: 'EQ-01',
      areaId: 'A1',
      maintenanceType: 'Mecánico y Calibración',
      frequency: ScheduleFrequency.biweekly,
      startDate: now,
      nextDate: now.add(const Duration(days: 15)),
      status: ScheduleStatus.active,
    );

    when(() => mockRepo.amendSchedule(
          scheduleId: any(named: 'scheduleId'),
          amendmentDocNumber: any(named: 'amendmentDocNumber'),
          authorizedByManager: any(named: 'authorizedByManager'),
          amendmentReason: any(named: 'amendmentReason'),
          updatedSchedule: any(named: 'updatedSchedule'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
        )).thenAnswer((_) async {});

    when(() => mockRepo.getAllSchedules(
          areaId: any(named: 'areaId'),
          status: any(named: 'status'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer((_) async => [updated]);

    final ok = await viewModel.amendSchedule(
      scheduleId: 'PM-2026-0001',
      amendmentDocNumber: 'OF-GER-2026-045',
      authorizedByManager: 'Ing. Carlos Ramos',
      amendmentReason: 'Actualización de frecuencia a quincenal',
      updatedSchedule: updated,
      userId: 'admin',
      userName: 'Gestor del Sistema',
    );

    expect(ok, isTrue);
    expect(viewModel.successMessage, contains('OF-GER-2026-045'));
  });

  test('toggleScheduleStatus pausa o reactiva el plan con autorización gerencial', () async {
    when(() => mockRepo.toggleScheduleStatus(
          scheduleId: any(named: 'scheduleId'),
          status: any(named: 'status'),
          amendmentDocNumber: any(named: 'amendmentDocNumber'),
          authorizedByManager: any(named: 'authorizedByManager'),
          reason: any(named: 'reason'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
        )).thenAnswer((_) async {});

    when(() => mockRepo.getAllSchedules(
          areaId: any(named: 'areaId'),
          status: any(named: 'status'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer((_) async => []);

    final ok = await viewModel.toggleScheduleStatus(
      scheduleId: 'PM-2026-0001',
      status: ScheduleStatus.paused,
      amendmentDocNumber: 'OF-GER-2026-115',
      authorizedByManager: 'Ing. Carlos Ramos',
      reason: 'Equipo en reacondicionamiento mayor',
      userId: 'admin',
      userName: 'Gestor del Sistema',
    );

    expect(ok, isTrue);
    expect(viewModel.successMessage, contains('OF-GER-2026-115'));
  });
}
