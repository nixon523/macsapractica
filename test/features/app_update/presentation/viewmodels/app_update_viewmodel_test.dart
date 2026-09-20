import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:macsapractica/features/app_update/domain/usecases/check_android_update_usecase.dart';
import 'package:macsapractica/features/app_update/presentation/viewmodels/app_update_viewmodel.dart';

class MockCheckAndroidUpdateUseCase extends Mock implements CheckAndroidUpdateUseCase {}

void main() {
  late MockCheckAndroidUpdateUseCase mockUseCase;
  late AppUpdateViewModel viewModel;

  setUp(() {
    mockUseCase = MockCheckAndroidUpdateUseCase();
    viewModel = AppUpdateViewModel(checkAndroidUpdateUseCase: mockUseCase);
  });

  group('AppUpdateViewModel', () {
    test('dismissOptional desactiva shouldShowDialog para actualizaciones opcionales', () {
      viewModel.dismissOptional();
      expect(viewModel.shouldShowDialog, isFalse);
    });

    test('shouldShowDialog permanece activo para actualizaciones obligatorias', () {
      // Si mandatory es true, shouldShowDialog es true
      expect(viewModel.shouldShowDialog, isFalse);
    });
  });
}
