import '../entities/area.dart';

abstract class AreaRepository {
  Future<List<Area>> getAreas({bool forceRefresh = false});

  Future<String> getNextAreaId();

  Future<Area> createArea({
    required String name,
    required String costCenter,
    String? customId,
  });

  Future<void> updateArea({
    required String id,
    required String name,
    String? costCenter,
  });

  Future<void> deleteArea(String id);
}

