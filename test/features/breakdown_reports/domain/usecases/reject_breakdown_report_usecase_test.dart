import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/error/failures.dart';
import 'package:macsapractica/features/breakdown_reports/domain/repositories/breakdown_report_repository.dart';
import 'package:macsapractica/features/breakdown_reports/domain/usecases/reject_breakdown_report.dart';
import 'package:mocktail/mocktail.dart';

class MockBreakdownReportRepository extends Mock
    implements BreakdownReportRepository {}

void main() {
  late MockBreakdownReportRepository repository;
  late RejectBreakdownReportUseCase useCase;

  setUp(() {
    repository = MockBreakdownReportRepository();
    useCase = RejectBreakdownReportUseCase(repository);
  });

  test('rechaza el reporte delegando en el repositorio', () async {
    when(() => repository.rejectReport(
          reportId: any(named: 'reportId'),
          reason: any(named: 'reason'),
          rejectedByUserId: any(named: 'rejectedByUserId'),
          rejectedByUserName: any(named: 'rejectedByUserName'),
        )).thenAnswer((_) async {});

    await useCase(
      const RejectBreakdownReportParams(
        reportId: 'br-002',
        reason: 'Vibración dentro de rango aceptable.',
        rejectedByUserId: 'admin',
        rejectedByUserName: 'Administrador General',
      ),
    );

    verify(() => repository.rejectReport(
          reportId: 'br-002',
          reason: 'Vibración dentro de rango aceptable.',
          rejectedByUserId: 'admin',
          rejectedByUserName: 'Administrador General',
        )).called(1);
  });

  test('exige un motivo de rechazo', () {
    expect(
      () => useCase(
        const RejectBreakdownReportParams(
          reportId: 'br-002',
          reason: '   ',
          rejectedByUserId: 'admin',
          rejectedByUserName: 'Administrador General',
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
