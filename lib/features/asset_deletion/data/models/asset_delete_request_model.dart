import '../../domain/entities/asset_delete_request.dart';

class AssetDeleteRequestModel extends AssetDeleteRequest {
  const AssetDeleteRequestModel({
    required super.id,
    required super.assetId,
    required super.assetName,
    required super.areaId,
    required super.status,
    required super.reason,
    required super.requestedByUserId,
    required super.requestedByUserName,
    required super.requestedAt,
    required super.subtreeCount,
    super.decidedByUserId,
    super.decidedByUserName,
    super.decidedAt,
    super.decisionReason,
  });

  factory AssetDeleteRequestModel.fromJson(
    Map<String, dynamic> map, [
    String? docId,
  ]) {
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
        (map['requestId'] ?? map['RequestId'] ?? map['id'] ?? '')?.toString() ??
        '';

    final statusStr =
        (map['status'] ?? map['Status'] ?? 'pending').toString();
    final status = DeletionRequestStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => DeletionRequestStatus.pending,
    );

    final subtreeVal = map['subtreeCount'] ?? map['SubtreeCount'] ?? 0;
    final subtreeCount = subtreeVal is int
        ? subtreeVal
        : int.tryParse(subtreeVal.toString()) ?? 0;

    return AssetDeleteRequestModel(
      id: id,
      assetId: (map['assetId'] ?? map['AssetCode'] ?? map['assetCode'] ?? '')
          .toString(),
      assetName: (map['assetName'] ?? map['AssetName'] ?? '').toString(),
      areaId: (map['areaId'] ?? map['AreaId'] ?? '').toString(),
      status: status,
      reason: (map['reason'] ?? map['Reason'] ?? '').toString(),
      requestedByUserId:
          (map['requestedByUserId'] ?? map['RequestedByUserId'] ?? '')
              .toString(),
      requestedByUserName:
          (map['requestedByUserName'] ?? map['RequestedByUserName'] ?? '')
              .toString(),
      requestedAt: parseDate(map['requestedAt'] ?? map['RequestedAt']),
      subtreeCount: subtreeCount,
      decidedByUserId:
          (map['decidedByUserId'] ?? map['DecidedByUserId'])?.toString(),
      decidedByUserName:
          (map['decidedByUserName'] ?? map['DecidedByUserName'])?.toString(),
      decidedAt: parseDate(map['decidedAt'] ?? map['DecidedAt']),
      decisionReason: (map['decisionReason'] ??
              map['DecisionReason'] ??
              map['resolutionReason'])
          ?.toString(),
    );
  }

  factory AssetDeleteRequestModel.fromFirestore(
    Map<String, dynamic> map,
    String docId,
  ) {
    return AssetDeleteRequestModel.fromJson(map, docId);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetCode': assetId,
      'assetName': assetName,
      'areaId': areaId,
      'status': status.name,
      'reason': reason,
      'requestedByUserId': requestedByUserId,
      'requestedByUserName': requestedByUserName,
      'subtreeCount': subtreeCount,
      if (decidedByUserId != null) 'decidedByUserId': decidedByUserId,
      if (decidedByUserName != null) 'decidedByUserName': decidedByUserName,
      if (decisionReason != null) 'decisionReason': decisionReason,
    };
  }
}
