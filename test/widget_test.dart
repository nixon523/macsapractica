import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:macsapractica/core/usecases/usecase.dart';
import 'package:macsapractica/features/assets/domain/entities/area.dart';
import 'package:macsapractica/features/assets/domain/usecases/get_areas_usecase.dart';
import 'package:macsapractica/features/assets/presentation/views/area_selection_view.dart';
import 'package:macsapractica/features/assets/presentation/viewmodels/area_list_viewmodel.dart';
import 'package:macsapractica/features/auth_permissions/domain/entities/app_user.dart';
import 'package:macsapractica/features/auth_permissions/domain/entities/user_role.dart';
import 'package:macsapractica/features/auth_permissions/domain/usecases/login.dart';
import 'package:macsapractica/features/auth_permissions/domain/usecases/change_password_usecase.dart';
import 'package:macsapractica/features/auth_permissions/domain/usecases/request_password_reset_usecase.dart';
import 'package:macsapractica/features/auth_permissions/presentation/viewmodels/auth_viewmodel.dart';

class MockGetAreasUseCase extends Mock implements GetAreasUseCase {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockChangePasswordUseCase extends Mock implements ChangePasswordUseCase {}

class MockRequestPasswordResetUseCase extends Mock
    implements RequestPasswordResetUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const LoginParams(username: 'admin', password: '1234'),
    );
  });

  testWidgets('AreaSelectionView muestra las áreas de Grupo Macsa', (tester) async {
    const areas = [
      Area(id: 'A1', name: 'Procesadora', costCenter: 'CC-01'),
      Area(id: 'A2', name: 'Empacadora', costCenter: 'CC-02'),
      Area(id: 'A3', name: 'Cámaras', costCenter: 'CC-03'),
    ];

    final useCase = MockGetAreasUseCase();
    when(() => useCase(any())).thenAnswer((_) async => areas);

    final loginUseCase = MockLoginUseCase();
    when(() => loginUseCase(any())).thenAnswer(
      (_) async => const AppUser(
        userId: 'u1',
        username: 'admin',
        role: UserRole.admin,
      ),
    );
    final authViewModel = AuthViewModel(
      loginUseCase: loginUseCase,
      changePasswordUseCase: MockChangePasswordUseCase(),
      requestPasswordResetUseCase: MockRequestPasswordResetUseCase(),
    );
    await authViewModel.login(username: 'admin', password: '1234');

    final viewModel = AreaListViewModel(getAreasUseCase: useCase);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
          ChangeNotifierProvider<AreaListViewModel>.value(value: viewModel),
        ],
        child: const MaterialApp(home: AreaSelectionView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Área A1'), findsOneWidget);
    expect(find.text('Área A2'), findsOneWidget);
    expect(find.text('Área A3'), findsOneWidget);
  });
}
