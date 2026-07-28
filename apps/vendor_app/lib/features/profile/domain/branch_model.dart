class BranchModel {
  final String id;
  final String? branchOfId;
  final String businessName;
  final String ownerName;
  final String city;
  final String? locality;
  final double? latitude;
  final double? longitude;
  final String verificationStatus;
  final DateTime createdAt;

  BranchModel({
    required this.id,
    this.branchOfId,
    required this.businessName,
    required this.ownerName,
    required this.city,
    this.locality,
    this.latitude,
    this.longitude,
    required this.verificationStatus,
    required this.createdAt,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id']?.toString() ?? '',
      branchOfId: json['branchOfId']?.toString(),
      businessName: json['businessName']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      locality: json['locality']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      verificationStatus: json['verificationStatus']?.toString() ?? json['status']?.toString() ?? 'PENDING',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
