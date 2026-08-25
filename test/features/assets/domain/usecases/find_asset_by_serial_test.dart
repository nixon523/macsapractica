import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/assets/domain/entities/asset.dart';
import 'package:macsapractica/features/assets/domain/repositories/asset_repository.dart';
import 'package:macsapractica/features/assets/domain/usecases/find_asset_by_serial.dart';
import 'package:mocktail/mocktail.dart';

class MockAssetRepository extends Mock implements AssetRepository {}

const _testAsset = Asset(
  id: 'A3-002',
  name: 'Bomba Centrífuga',
  areaId: 'A3',
  stationId: 'EST-03',
  level: AssetLevel.equipment,
  ancestors: [],
  status: AssetStatus.active,
  dynamicAttributes: {},
  serial: 'SN-2024-00142',
);

void main() {
  late MockAssetRepository repository;
  late FindAssetBySerialUseCase useCase;

  setUpAll(() {
    registerFallbackValue('SN-2024-00142');
  });

  setUp(() {
    repository = MockAssetRepository();
    useCase = FindAssetBySerialUseCase(repository);
  });

  test('retorna null cuando el serial no existe', () async {
    when(() => repository.findAssetBySerial(any()))
        .thenAnswer((_) async => null);

    final result = await useCase(const FindAssetBySerialParams('SN-NUEVO'));

    expect(result, isNull);
    verify(() => repository.findAssetBySerial('SN-NUEVO')).called(1);
  });

  test('retorna el activo existente cuando el serial ya está registrado',
      () async {
    when(() => repository.findAssetBySerial(any()))
        .thenAnswer((_) async => _testAsset);

    final result =
        await useCase(const FindAssetBySerialParams('SN-2024-00142'));

    expect(result, equals(_testAsset));
    expect(result!.id, equals('A3-002'));
    expect(result.areaId, equals('A3'));
    verify(() => repository.findAssetBySerial('SN-2024-00142')).called(1);
  });

  test('retorna null y no llama al repositorio cuando el serial está vacío',
      () async {
    final result = await useCase(const FindAssetBySerialParams(''));

    expect(result, isNull);
    verifyNever(() => repository.findAssetBySerial(any()));
  });

  test('retorna null y no llama al repositorio cuando el serial es solo espacios',
      () async {
    final result = await useCase(const FindAssetBySerialParams('   '));

    expect(result, isNull);
    verifyNever(() => repository.findAssetBySerial(any()));
  });

  test('hace trim al serial antes de consultar el repositorio', () async {
    when(() => repository.findAssetBySerial(any()))
        .thenAnswer((_) async => null);

    await useCase(const FindAssetBySerialParams('  SN-001  '));

    // El repositorio debe recibir el serial sin espacios
    verify(() => repository.findAssetBySerial('SN-001')).called(1);
  });
}
