import '../../domain/entities/kardex_log.dart';

class KardexLogModel extends KardexLog {
  const KardexLogModel({
    required super.id,
    required super.timestamp,
    required super.userId,
    required super.userName,
    required super.action,
    required super.module,
    required super.entityId,
    required super.details,
  });

  factory KardexLogModel.fromJson(Map<String, dynamic> map, [String? docId]) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      try {
        return (d as dynamic).toDate();
      } catch (_) {
        if (d is String) return DateTime.tryParse(d);
      }
      return null;
    }

    final id = docId ??
        (map['logId'] ?? map['LogId'] ?? map['id'] ?? '')?.toString() ??
        '';

    return KardexLogModel(
      id: id,
      timestamp: parseDate(map['timestamp'] ?? map['LoggedAt'] ?? map['loggedAt']) ??
          DateTime.now(),
      userId: (map['userId'] ?? map['UserId'] ?? '').toString(),
      userName: (map['userName'] ?? map['UserName'] ?? '').toString(),
      action: (map['action'] ?? map['Action'] ?? '').toString(),
      module: (map['module'] ?? map['Module'] ?? '').toString(),
      entityId: (map['entityId'] ?? map['EntityId'] ?? '').toString(),
      details: (map['details'] ?? map['Details'] ?? '').toString(),
    );
  }

  factory KardexLogModel.fromFirestore(Map<String, dynamic> map, String docId) {
    return KardexLogModel.fromJson(map, docId);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'userName': userName,
      'action': action,
      'module': module,
      'entityId': entityId,
      'details': details,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'timestamp': timestamp,
      'userId': userId,
      'userName': userName,
      'action': action,
      'module': module,
      'entityId': entityId,
      'details': details,
    };
  }
}
