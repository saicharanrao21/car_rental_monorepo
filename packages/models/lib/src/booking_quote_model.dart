import 'package:equatable/equatable.dart';

class BookingQuoteLineItemModel extends Equatable {
  final String? id;
  final String type;
  final String name;
  final String? description;
  final double rate;
  final double quantity;
  final double amount;
  final bool isRefundable;
  final int displayOrder;

  const BookingQuoteLineItemModel({
    this.id,
    required this.type,
    required this.name,
    this.description,
    required this.rate,
    required this.quantity,
    required this.amount,
    this.isRefundable = false,
    this.displayOrder = 0,
  });

  factory BookingQuoteLineItemModel.fromJson(Map<String, dynamic> json) {
    return BookingQuoteLineItemModel(
      id: json['id'] as String?,
      type: (json['type'] as String?) ?? 'BASE_RENTAL',
      name: (json['name'] as String?) ?? 'Line Item',
      description: json['description'] as String?,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      isRefundable: (json['isRefundable'] as bool?) ?? false,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'type': type,
    'name': name,
    if (description != null) 'description': description,
    'rate': rate,
    'quantity': quantity,
    'amount': amount,
    'isRefundable': isRefundable,
    'displayOrder': displayOrder,
  };

  @override
  List<Object?> get props => [
    id,
    type,
    name,
    description,
    rate,
    quantity,
    amount,
    isRefundable,
    displayOrder,
  ];
}

class BookingQuoteModel extends Equatable {
  final String quoteId;
  final String tenantId;
  final String carId;
  final String vehicleName;
  final String registrationNumber;
  final String tripType;
  final DateTime startDate;
  final DateTime endDate;
  final int durationDays;
  final int durationHours;
  final String currency;
  final String pricingVersion;
  final double subtotal;
  final double discountTotal;
  final double feesTotal;
  final double taxTotal;
  final double depositTotal;
  final double tripFare;
  final double totalPayable;
  final double netToVendor;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final List<BookingQuoteLineItemModel> lineItems;
  final Map<String, dynamic>? metadata;

  const BookingQuoteModel({
    required this.quoteId,
    required this.tenantId,
    required this.carId,
    required this.vehicleName,
    required this.registrationNumber,
    required this.tripType,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.durationHours,
    this.currency = 'INR',
    this.pricingVersion = 'v1.0',
    required this.subtotal,
    required this.discountTotal,
    required this.feesTotal,
    required this.taxTotal,
    required this.depositTotal,
    required this.tripFare,
    required this.totalPayable,
    required this.netToVendor,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.acceptedAt,
    this.lineItems = const [],
    this.metadata,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get remainingSeconds =>
      expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999999);

  factory BookingQuoteModel.fromJson(Map<String, dynamic> json) {
    return BookingQuoteModel(
      quoteId: (json['quoteId'] ?? json['id'] ?? '') as String,
      tenantId: (json['tenantId'] ?? '') as String,
      carId: (json['carId'] ?? '') as String,
      vehicleName: (json['vehicleName'] ?? 'Vehicle') as String,
      registrationNumber: (json['registrationNumber'] ?? '') as String,
      tripType: (json['tripType'] ?? 'SELF_DRIVE') as String,
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now(),
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 1,
      durationHours: (json['durationHours'] as num?)?.toInt() ?? 24,
      currency: (json['currency'] ?? 'INR') as String,
      pricingVersion: (json['pricingVersion'] ?? 'v1.0') as String,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountTotal: (json['discountTotal'] as num?)?.toDouble() ?? 0.0,
      feesTotal: (json['feesTotal'] as num?)?.toDouble() ?? 0.0,
      taxTotal: (json['taxTotal'] as num?)?.toDouble() ?? 0.0,
      depositTotal: (json['depositTotal'] as num?)?.toDouble() ?? 0.0,
      tripFare: (json['tripFare'] as num?)?.toDouble() ?? 0.0,
      totalPayable: (json['totalPayable'] as num?)?.toDouble() ?? 0.0,
      netToVendor: (json['netToVendor'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] ?? 'ACTIVE') as String,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ?? DateTime.now().add(const Duration(minutes: 15)),
      acceptedAt: json['acceptedAt'] != null ? DateTime.tryParse(json['acceptedAt'].toString()) : null,
      lineItems: (json['lineItems'] as List<dynamic>?)
              ?.map((e) => BookingQuoteLineItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'quoteId': quoteId,
    'tenantId': tenantId,
    'carId': carId,
    'vehicleName': vehicleName,
    'registrationNumber': registrationNumber,
    'tripType': tripType,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'durationDays': durationDays,
    'durationHours': durationHours,
    'currency': currency,
    'pricingVersion': pricingVersion,
    'subtotal': subtotal,
    'discountTotal': discountTotal,
    'feesTotal': feesTotal,
    'taxTotal': taxTotal,
    'depositTotal': depositTotal,
    'tripFare': tripFare,
    'totalPayable': totalPayable,
    'netToVendor': netToVendor,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
    'lineItems': lineItems.map((e) => e.toJson()).toList(),
    if (metadata != null) 'metadata': metadata,
  };

  @override
  List<Object?> get props => [
    quoteId,
    tenantId,
    carId,
    vehicleName,
    registrationNumber,
    tripType,
    startDate,
    endDate,
    durationDays,
    durationHours,
    currency,
    pricingVersion,
    subtotal,
    discountTotal,
    feesTotal,
    taxTotal,
    depositTotal,
    tripFare,
    totalPayable,
    netToVendor,
    status,
    createdAt,
    expiresAt,
    acceptedAt,
    lineItems,
    metadata,
  ];
}
