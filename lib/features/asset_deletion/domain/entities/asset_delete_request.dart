enum DeletionRequestStatus { pending, approved, rejected }

class AssetDeleteRequest {
  const AssetDeleteRequest({
    required this.id,
    required this.assetId,
    required this.assetName,
    required this.areaId,
    required this.status,
    required this.reason,
    required this.requestedByUserId,
    required this.requestedByUserName,
    required this.requestedAt,
    required this.subtreeCount,
    this.decidedByUserId,
    this.decidedByUserName,
    this.decidedAt,
    this.decisionReason,
  });

  final String id;
  final String assetId;
  final String assetName;
  final String areaId;
  final DeletionRequestStatus status;
  final String reason;
  final String requestedByUserId;
  final String requestedByUserName;
  final DateTime? requestedAt;
  final int subtreeCount;

  /// Usuario (gerente) que aprobó o rechazó la solicitud.
  final String? decidedByUserId;
  final String? decidedByUserName;
  final DateTime? decidedAt;

  /// Motivo de la aprobación o del rechazo.
  final String? decisionReason;

  bool get isPending => status == DeletionRequestStatus.pending;
}
