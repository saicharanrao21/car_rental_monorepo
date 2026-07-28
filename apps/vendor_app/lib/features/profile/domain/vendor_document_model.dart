class VendorDocumentModel {
  final String id;
  final String vendorId;
  final String? carId;
  final String type; // RC_BOOK, TRADE_LICENSE, INSURANCE, etc.
  final String fileUrl;
  final String status; // PENDING, VERIFIED, REJECTED
  final DateTime? expiresAt;
  final DateTime uploadedAt;

  VendorDocumentModel({
    required this.id,
    required this.vendorId,
    this.carId,
    required this.type,
    required this.fileUrl,
    required this.status,
    this.expiresAt,
    required this.uploadedAt,
  });

  factory VendorDocumentModel.fromJson(Map<String, dynamic> json) {
    return VendorDocumentModel(
      id: json['id']?.toString() ?? '',
      vendorId: json['vendorId']?.toString() ?? '',
      carId: json['carId']?.toString(),
      type: json['type']?.toString() ?? '',
      fileUrl: json['fileUrl']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'].toString()) : null,
      uploadedAt: json['uploadedAt'] != null ? DateTime.tryParse(json['uploadedAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
