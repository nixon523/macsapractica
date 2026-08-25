import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/auth_permissions/domain/entities/app_user.dart';
import 'package:macsapractica/features/auth_permissions/domain/repositories/auth_repository.dart';
import 'package:macsapractica/features/auth_permissions/domain/usecases/login.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late LoginUseCase useCase;

  const admin = AppUser(
    userId: 'u1',
    username: 'admin',
    displayName: 'Administrador',
    permissions: {'asset.create'},
  );

  setUpAll(() {
    registerFallbackValue(const LoginParams(username: 'admin', password: 'x'));
  });

  setUp(() {
    repository = MockAuthRepository();
    useCase = LoginUseCase(repository);
  });

  test('devuelve el usuario cuando las credenciales son válidas', () async {
    when(() => repository.login(
          username: any(named: 'username'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => admin);

    final result = await useCase(
      const LoginParams(username: ' admin ', password: 'secret123'),
    );

    expect(result, admin);
    verify(() => repository.login(
          username: 'admin',
          password: 'secret123',
        )).called(1);
  });

  test('devuelve null cuando las credenciales son inválidas', () async {
    when(() => repository.login(
          username: any(named: 'username'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => null);

    final result = await useCase(
      const LoginParams(username: 'admin', password: 'incorrecta'),
    );

    expect(result, isNull);
  });
}
