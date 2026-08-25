class KardexLog {
  const KardexLog({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.userName,
    required this.action,
    required this.module,
    required this.entityId,
    required this.details,
  });

  final String id;
  final DateTime timestamp;
  final String userId;
  final String userName;
  final String action;
  final String module;
  final String entityId;
  final String details;
}
