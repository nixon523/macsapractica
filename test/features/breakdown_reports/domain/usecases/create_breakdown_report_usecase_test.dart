import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/error/failures.dart';
import 'package:macsapractica/features/breakdown_reports/domain/entities/breakdown_report.dart';
import 'package:macsapractica/features/breakdown_reports/domain/repositories/breakdown_report_repository.dart';
import 'package:macsapractica/features/breakdown_reports/domain/usecases/create_breakdown_report.dart';
import 'package:mocktail/mocktail.dart';

class MockBreakdownReportRepository extends Mock
    implements BreakdownReportRepository {}

void main() {
  late MockBreakdownReportRepository repository;
  late CreateBreakdownReportUseCase useCase;

  const params = CreateBreakdownReportParams(
    assetId: 'A1-001',
    assetName: 'Bomba centrífuga',
    areaId: 'A1',
    description: 'Fuga de aceite en el sello mecánico',
    severity: BreakdownSeverity.high,
    reportedByUserId: 'reportador',
    reportedByUserName: 'Reportador de Averías',
  );

  setUpAll(() {
    registerFallbackValue(BreakdownSeverity.medium);
  });

  setUp(() {
    repository = MockBreakdownReportRepository();
    useCase = CreateBreakdownReportUseCase(repository);
  });

  test('crea el reporte delegando en el repositorio', () async {
    const created = BreakdownReport(
      id: 'br1',
      assetId: 'A1-001',
      assetName: 'Bomba centrífuga',
      areaId: 'A1',
      description: 'Fuga de aceite en el sello mecánico',
      severity: BreakdownSeverity.high,
      reportedByUserId: 'reportador',
      reportedByUserName: 'Reportador de Averías',
      reportedAt: null,
      status: BreakdownReportStatus.reported,
    );
    when(() => repository.createReport(
          assetId: any(named: 'assetId'),
          assetName: any(named: 'assetName'),
          areaId: any(named: 'areaId'),
          description: any(named: 'description'),
          severity: any(named: 'severity'),
          reportedByUserId: any(named: 'reportedByUserId'),
          reportedByUserName: any(named: 'reportedByUserName'),
        )).thenAnswer((_) async => created);

    final result = await useCase(params);

    expect(result.id, 'br1');
    verify(() => repository.createReport(
          assetId: 'A1-001',
          assetName: 'Bomba centrífuga',
          areaId: 'A1',
          description: 'Fuga de aceite en el sello mecánico',
          severity: BreakdownSeverity.high,
          reportedByUserId: 'reportador',
          reportedByUserName: 'Reportador de Averías',
        )).called(1);
  });

  test('no permite descripciones vacías', () {
    expect(
      () => useCase(
        const CreateBreakdownReportParams(
          assetId: 'A1-001',
          assetName: 'Bomba',
          areaId: 'A1',
          description: '   ',
          severity: BreakdownSeverity.low,
          reportedByUserId: 'r',
          reportedByUserName: 'R',
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
