enum AssetLevel { equipment, subEquipment, part, subPart }

enum AssetStatus { active, transferredDeactivated, inactive, deleted }

class AssetStatusPeriod {
  final String? id;
  final AssetStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String areaId;
  final String? reason;
  final String? userId;
  final String? userName;

  const AssetStatusPeriod({
    this.id,
    required this.status,
    required this.startedAt,
    this.endedAt,
    required this.areaId,
    this.reason,
    this.userId,
    this.userName,
  });

  bool get isCurrent => endedAt == null;

  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.isAfter(startedAt) ? end.difference(startedAt) : Duration.zero;
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'areaId': areaId,
      if (reason != null) 'reason': reason,
      if (userId != null) 'userId': userId,
      if (userName != null) 'userName': userName,
    };
  }

  factory AssetStatusPeriod.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d is DateTime) return d;
      if (d != null) {
        if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
        try {
          return (d as dynamic).toDate();
        } catch (_) {}
      }
      return DateTime.now();
    }

    return AssetStatusPeriod(
      status: AssetStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AssetStatus.active,
      ),
      startedAt: parseDate(map['startedAt']),
      endedAt: map['endedAt'] != null ? parseDate(map['endedAt']) : null,
      areaId: map['areaId']?.toString() ?? '',
      reason: map['reason'] as String?,
      userId: map['userId'] as String?,
      userName: map['userName'] as String?,
    );
  }
}

class Asset {
  final String id;
  final String name;
  final String? brand;
  final String? model;
  final String areaId;
  final String stationId;
  final String? parentAssetId;
  final AssetLevel level;
  final List<String> ancestors;
  final AssetStatus status;
  final String? transferredToId;
  final Map<String, dynamic> dynamicAttributes;
  final String? imageData;
  final String? serial;
  final List<AssetStatusPeriod> statusHistory;
  final DateTime? createdAt;
  /// Indica si este activo de primer nivel es un equipo de proceso
  /// (requiere reporte semanal de disponibilidad operativa).
  final bool esEquipoProceso;

  const Asset({
    required this.id,
    required this.name,
    this.brand,
    this.model,
    required this.areaId,
    required this.stationId,
    this.parentAssetId,
    required this.level,
    required this.ancestors,
    required this.status,
    this.transferredToId,
    required this.dynamicAttributes,
    this.imageData,
    this.serial,
    this.statusHistory = const [],
    this.createdAt,
    this.esEquipoProceso = false,
  });

  // ignore: avoid_positional_boolean_parameters
  Asset copyWith({
    String? name,
    String? brand,
    String? model,
    String? areaId,
    String? stationId,
    String? parentAssetId,
    AssetLevel? level,
    List<String>? ancestors,
    AssetStatus? status,
    String? transferredToId,
    Map<String, dynamic>? dynamicAttributes,
    String? imageData,
    List<AssetStatusPeriod>? statusHistory,
    DateTime? createdAt,
    bool? esEquipoProceso,
    // serial es inmutable — no se puede cambiar con copyWith
  }) {
    return Asset(
      id: id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      areaId: areaId ?? this.areaId,
      stationId: stationId ?? this.stationId,
      parentAssetId: parentAssetId ?? this.parentAssetId,
      level: level ?? this.level,
      ancestors: ancestors ?? this.ancestors,
      status: status ?? this.status,
      transferredToId: transferredToId ?? this.transferredToId,
      dynamicAttributes: dynamicAttributes ?? this.dynamicAttributes,
      imageData: imageData ?? this.imageData,
      serial: serial,
      statusHistory: statusHistory ?? this.statusHistory,
      createdAt: createdAt ?? this.createdAt,
      esEquipoProceso: esEquipoProceso ?? this.esEquipoProceso,
    );
  }

  bool get isActive => status == AssetStatus.active;
  bool get isInactive => status == AssetStatus.inactive;

  Duration get totalUptime {
    var total = Duration.zero;
    for (final p in statusHistory) {
      if (p.status == AssetStatus.active) {
        total += p.duration;
      }
    }
    if (total == Duration.zero && status == AssetStatus.active) {
      final start = createdAt ?? DateTime(2026, 8, 1);
      final diff = DateTime.now().difference(start);
      total = diff.isNegative ? Duration.zero : diff;
    }
    return total;
  }

  Duration get totalDowntime {
    var total = Duration.zero;
    for (final p in statusHistory) {
      if (p.status == AssetStatus.inactive) {
        total += p.duration;
      }
    }
    return total;
  }

  int get inactiveCount =>
      statusHistory.where((p) => p.status == AssetStatus.inactive).length;

  double get availabilityPercentage {
    final up = totalUptime.inSeconds;
    final down = totalDowntime.inSeconds;
    final total = up + down;
    if (total == 0) return 100.0;
    return ((up / total) * 100).clamp(0.0, 100.0);
  }

  /// Normaliza texto libre a tokens de búsqueda: minúsculas, sin acentos,
  /// separados por espacios y signos, sin duplicados y limitados a 10 para
  /// `arrayContainsAny`. Quitar acentos permite que "centrifuga" coincida con
  /// "centrífuga".
  static List<String> tokenize(String text) {
    const accents = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
      'ü': 'u', 'ñ': 'n',
    };
    final normalized = text.toLowerCase().split('').map((c) {
      return accents[c] ?? c;
    }).join();

    final tokens = <String>{};
    for (final part in normalized.split(RegExp(r'\s+|-|\.|/'))) {
      final token = part.trim();
      if (token.isNotEmpty) tokens.add(token);
    }
    return tokens.take(10).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Asset &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          brand == other.brand &&
          model == other.model &&
          areaId == other.areaId &&
          stationId == other.stationId &&
          parentAssetId == other.parentAssetId &&
          level == other.level &&
          status == other.status &&
          transferredToId == other.transferredToId &&
          imageData == other.imageData &&
          serial == other.serial;

  @override
  int get hashCode => Object.hash(
        id, name, brand, model, areaId, stationId,
        parentAssetId, level, status, transferredToId, imageData, serial,
      );
}
