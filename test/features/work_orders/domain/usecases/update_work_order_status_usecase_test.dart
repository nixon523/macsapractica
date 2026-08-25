import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/work_orders/domain/entities/work_order.dart';
import 'package:macsapractica/features/work_orders/domain/repositories/work_order_repository.dart';
import 'package:macsapractica/features/work_orders/domain/usecases/update_work_order_status.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkOrderRepository extends Mock implements WorkOrderRepository {}

void main() {
  late MockWorkOrderRepository repository;
  late UpdateWorkOrderStatusUseCase useCase;

  setUpAll(() {
    registerFallbackValue(WorkOrderStatus.pending);
    registerFallbackValue('admin');
    registerFallbackValue('Gestor del Sistema');
  });

  setUp(() {
    repository = MockWorkOrderRepository();
    useCase = UpdateWorkOrderStatusUseCase(repository);
  });

  test('actualiza el estado delegando en el repositorio', () async {
    when(() => repository.updateStatus(
          workOrderId: any(named: 'workOrderId'),
          status: any(named: 'status'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
        )).thenAnswer((_) async {});

    await useCase(
      UpdateWorkOrderStatusParams(
        workOrderId: 'OT-0001',
        status: WorkOrderStatus.inProgress,
        userId: 'admin',
        userName: 'Gestor del Sistema',
      ),
    );

    verify(() => repository.updateStatus(
          workOrderId: 'OT-0001',
          status: WorkOrderStatus.inProgress,
          userId: 'admin',
          userName: 'Gestor del Sistema',
        )).called(1);
  });
}
