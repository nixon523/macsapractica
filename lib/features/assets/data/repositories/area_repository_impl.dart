import '../../domain/entities/area.dart';
import '../../domain/repositories/area_repository.dart';
import '../datasources/area_remote_datasource.dart';

class AreaRepositoryImpl implements AreaRepository {
  const AreaRepositoryImpl({
    required this.remoteDataSource,
  });

  final AreaRemoteDataSource remoteDataSource;

  @override
  Future<List<Area>> getAreas({bool forceRefresh = false}) async {
    return remoteDataSource.getAreas();
  }

  @override
  Future<String> getNextAreaId() async {
    final areas = await remoteDataSource.getAreas();
    int maxNum = 0;
    for (final area in areas) {
      if (area.id.startsWith('A')) {
        final numPart = int.tryParse(area.id.substring(1));
        if (numPart != null && numPart > maxNum) {
          maxNum = numPart;
        }
      }
    }
    return 'A${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  @override
  Future<Area> createArea({
    required String name,
    required String costCenter,
    String? customId,
  }) async {
    final formattedCc = costCenter.trim().startsWith('CC-')
        ? costCenter.trim()
        : (costCenter.trim().startsWith('CC')
            ? costCenter.trim()
            : 'CC-${costCenter.trim()}');

    return remoteDataSource.createArea(
      name: name,
      costCenter: formattedCc,
      customId: customId,
    );
  }

  @override
  Future<void> updateArea({
    required String id,
    required String name,
    String? costCenter,
  }) async {
    final formattedCc = costCenter != null && costCenter.isNotEmpty
        ? (costCenter.trim().startsWith('CC-')
            ? costCenter.trim()
            : (costCenter.trim().startsWith('CC')
                ? costCenter.trim()
                : 'CC-${costCenter.trim()}'))
        : null;

    return remoteDataSource.updateArea(
      id: id,
      name: name,
      costCenter: formattedCc,
    );
  }
}
