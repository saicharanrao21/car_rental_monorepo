class DisputeEvidenceModel {
  final String id;
  final String disputeId;
  final String fileUrl;
  final String fileType;
  final DateTime createdAt;

  DisputeEvidenceModel({
    required this.id,
    required this.disputeId,
    required this.fileUrl,
    required this.fileType,
    required this.createdAt,
  });

  factory DisputeEvidenceModel.fromJson(Map<String, dynamic> json) {
    return DisputeEvidenceModel(
      id: json['id']?.toString() ?? '',
      disputeId: json['disputeId']?.toString() ?? '',
      fileUrl: json['fileUrl']?.toString() ?? '',
      fileType: json['fileType']?.toString() ?? 'image',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class DisputeModel {
  final String id;
  final String bookingId;
  final String raisedByRole; // CUSTOMER or VENDOR
  final String raisedById;
  final String raisedByName;
  final String reason;
  final String status; // OPEN, UNDER_REVIEW, RESOLVED, REJECTED
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DisputeEvidenceModel> evidence;
  final Map<String, dynamic>? booking;

  DisputeModel({
    required this.id,
    required this.bookingId,
    required this.raisedByRole,
    required this.raisedById,
    required this.raisedByName,
    required this.reason,
    required this.status,
    this.resolutionNote,
    required this.createdAt,
    required this.updatedAt,
    required this.evidence,
    this.booking,
  });

  factory DisputeModel.fromJson(Map<String, dynamic> json) {
    final evList = (json['evidence'] as List? ?? [])
        .map((e) => DisputeEvidenceModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    String name = json['raisedByName'] ?? 'User';
    if (json['raisedBy'] != null && json['raisedBy'] is Map) {
      name = json['raisedBy']['name'] ?? name;
    }

    return DisputeModel(
      id: json['id']?.toString() ?? '',
      bookingId: json['bookingId']?.toString() ?? '',
      raisedByRole: json['raisedByRole']?.toString() ?? 'CUSTOMER',
      raisedById: json['raisedById']?.toString() ?? '',
      raisedByName: name,
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      resolutionNote: json['resolutionNote']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now() : DateTime.now(),
      evidence: evList,
      booking: json['booking'] is Map ? Map<String, dynamic>.from(json['booking']) : null,
    );
  }
}
