import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/breakdown_reports/domain/entities/breakdown_report.dart';
import 'package:macsapractica/features/breakdown_reports/domain/usecases/link_breakdown_to_work_order.dart';
import 'package:macsapractica/features/work_orders/domain/entities/work_order.dart';
import 'package:macsapractica/features/work_orders/domain/usecases/create_work_order.dart';
import 'package:macsapractica/features/work_orders/presentation/viewmodels/work_order_create_viewmodel.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateWorkOrderUseCase extends Mock implements CreateWorkOrderUseCase {}

class MockLinkBreakdownToWorkOrderUseCase extends Mock
    implements LinkBreakdownToWorkOrderUseCase {}

void main() {
  late MockCreateWorkOrderUseCase createUseCase;
  late MockLinkBreakdownToWorkOrderUseCase linkUseCase;
  late WorkOrderCreateViewModel viewModel;

  const report = BreakdownReport(
    id: 'br1',
    assetId: 'A1-001',
    assetName: 'Bomba centrífuga',
    areaId: 'A1',
    description: 'Fuga de aceite',
    severity: BreakdownSeverity.high,
    reportedByUserId: 'reportador',
    reportedByUserName: 'Reportador',
    reportedAt: null,
    status: BreakdownReportStatus.reported,
  );

  setUpAll(() {
    registerFallbackValue(const CreateWorkOrderParams(
      assetId: 'A1-001',
      assetName: 'Bomba centrífuga',
      description: 'Fuga de aceite',
      createdByUserId: 'admin',
      createdByUserName: 'Gestor',
    ));
    registerFallbackValue(const LinkBreakdownToWorkOrderParams(
      reportId: 'br1',
      workOrderId: 'OT-0001',
      userId: 'admin',
      userName: 'Gestor',
    ));
  });

  setUp(() {
    createUseCase = MockCreateWorkOrderUseCase();
    linkUseCase = MockLinkBreakdownToWorkOrderUseCase();
    viewModel = WorkOrderCreateViewModel(
      createWorkOrderUseCase: createUseCase,
      linkBreakdownToWorkOrderUseCase: linkUseCase,
    );
  });

  test('exige ID de activo antes de crear', () async {
    final result = await viewModel.submit(userId: 'admin', userName: 'Gestor');
    expect(result, isNull);
    verifyNever(() => createUseCase.call(any()));
  });

  test('crea la OT y vincula el reporte cuando nace de uno', () async {
    when(() => createUseCase.call(any())).thenAnswer((_) async => const WorkOrder(
          id: 'OT-0001',
          assetId: 'A1-001',
          assetName: 'Bomba centrífuga',
          description: 'Fuga de aceite',
          status: WorkOrderStatus.pending,
        ));
    when(() => linkUseCase.call(any())).thenAnswer((_) async {});

    viewModel.initFromReport(report);
    final created =
        await viewModel.submit(userId: 'admin', userName: 'Gestor');

    expect(created!.id, 'OT-0001');
    verify(() => createUseCase.call(any())).called(1);
    verify(() => linkUseCase.call(
          any(
            that: isA<LinkBreakdownToWorkOrderParams>()
                .having((p) => p.reportId, 'reportId', 'br1')
                .having((p) => p.workOrderId, 'workOrderId', 'OT-0001'),
          ),
        )).called(1);
  });

  test('no vincula ningún reporte cuando la OT se crea en blanco', () async {
    when(() => createUseCase.call(any())).thenAnswer((_) async => const WorkOrder(
          id: 'OT-0002',
          assetId: 'A1-002',
          assetName: 'Compresor',
          description: 'Cambio de filtros',
          status: WorkOrderStatus.pending,
        ));

    viewModel.setAssetId('A1-002');
    viewModel.setAssetName('Compresor');
    viewModel.setDescription('Cambio de filtros');
    final created =
        await viewModel.submit(userId: 'admin', userName: 'Gestor');

    expect(created!.id, 'OT-0002');
    verifyNever(() => linkUseCase.call(any()));
  });
}
