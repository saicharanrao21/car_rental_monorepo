class RevenueSummaryModel {
  final double grossBookingValue;
  final double platformRevenue;
  final double vendorPayouts;
  final double gstCollected;
  final double baseFareRevenue;
  final double protectionRevenue;
  final double deliveryRevenue;
  final double discountTotal;
  final double refundTotal;
  final double netPlatformRevenue;
  final double walletLiability;
  final double loyaltyLiability;
  final double referralCost;

  const RevenueSummaryModel({
    required this.grossBookingValue,
    required this.platformRevenue,
    required this.vendorPayouts,
    required this.gstCollected,
    this.baseFareRevenue = 0.0,
    this.protectionRevenue = 0.0,
    this.deliveryRevenue = 0.0,
    this.discountTotal = 0.0,
    this.refundTotal = 0.0,
    this.netPlatformRevenue = 0.0,
    this.walletLiability = 0.0,
    this.loyaltyLiability = 0.0,
    this.referralCost = 0.0,
  });

  factory RevenueSummaryModel.fromJson(Map<String, dynamic> json) {
    return RevenueSummaryModel(
      grossBookingValue: (json['grossBookingValue'] as num?)?.toDouble() ?? 0.0,
      platformRevenue: (json['platformRevenue'] as num?)?.toDouble() ?? 0.0,
      vendorPayouts: (json['vendorPayouts'] as num?)?.toDouble() ?? 0.0,
      gstCollected: (json['gstCollected'] as num?)?.toDouble() ?? 0.0,
      baseFareRevenue: (json['baseFareRevenue'] as num?)?.toDouble() ?? 0.0,
      protectionRevenue: (json['protectionRevenue'] as num?)?.toDouble() ?? 0.0,
      deliveryRevenue: (json['deliveryRevenue'] as num?)?.toDouble() ?? 0.0,
      discountTotal: (json['discountTotal'] as num?)?.toDouble() ?? 0.0,
      refundTotal: (json['refundTotal'] as num?)?.toDouble() ?? 0.0,
      netPlatformRevenue: (json['netPlatformRevenue'] as num?)?.toDouble() ?? 0.0,
      walletLiability: (json['walletLiability'] as num?)?.toDouble() ?? 0.0,
      loyaltyLiability: (json['loyaltyLiability'] as num?)?.toDouble() ?? 0.0,
      referralCost: (json['referralCost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'grossBookingValue': grossBookingValue,
      'platformRevenue': platformRevenue,
      'vendorPayouts': vendorPayouts,
      'gstCollected': gstCollected,
      'baseFareRevenue': baseFareRevenue,
      'protectionRevenue': protectionRevenue,
      'deliveryRevenue': deliveryRevenue,
      'discountTotal': discountTotal,
      'refundTotal': refundTotal,
      'netPlatformRevenue': netPlatformRevenue,
      'walletLiability': walletLiability,
      'loyaltyLiability': loyaltyLiability,
      'referralCost': referralCost,
    };
  }
}

class BookingLifecycleStatsModel {
  final int totalBookings;
  final int completedBookings;
  final int cancelledBookings;
  final int confirmedBookings;
  final int ongoingBookings;
  final int pendingBookings;
  final double completionRate;
  final double cancellationRate;
  final double averageBookingValue;
  final double averageDurationDays;
  final Map<String, int> statusDistribution;

  const BookingLifecycleStatsModel({
    required this.totalBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.confirmedBookings,
    required this.ongoingBookings,
    required this.pendingBookings,
    required this.completionRate,
    required this.cancellationRate,
    required this.averageBookingValue,
    required this.averageDurationDays,
    required this.statusDistribution,
  });

  factory BookingLifecycleStatsModel.fromJson(Map<String, dynamic> json) {
    final distMap = <String, int>{};
    if (json['statusDistribution'] is Map) {
      (json['statusDistribution'] as Map).forEach((key, val) {
        distMap[key.toString()] = (val as num?)?.toInt() ?? 0;
      });
    }
    return BookingLifecycleStatsModel(
      totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
      completedBookings: (json['completedBookings'] as num?)?.toInt() ?? 0,
      cancelledBookings: (json['cancelledBookings'] as num?)?.toInt() ?? 0,
      confirmedBookings: (json['confirmedBookings'] as num?)?.toInt() ?? 0,
      ongoingBookings: (json['ongoingBookings'] as num?)?.toInt() ?? 0,
      pendingBookings: (json['pendingBookings'] as num?)?.toInt() ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0.0,
      cancellationRate: (json['cancellationRate'] as num?)?.toDouble() ?? 0.0,
      averageBookingValue: (json['averageBookingValue'] as num?)?.toDouble() ?? 0.0,
      averageDurationDays: (json['averageDurationDays'] as num?)?.toDouble() ?? 0.0,
      statusDistribution: distMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalBookings': totalBookings,
      'completedBookings': completedBookings,
      'cancelledBookings': cancelledBookings,
      'confirmedBookings': confirmedBookings,
      'ongoingBookings': ongoingBookings,
      'pendingBookings': pendingBookings,
      'completionRate': completionRate,
      'cancellationRate': cancellationRate,
      'averageBookingValue': averageBookingValue,
      'averageDurationDays': averageDurationDays,
      'statusDistribution': statusDistribution,
    };
  }
}

class FleetUtilizationModel {
  final int totalCars;
  final int availableCars;
  final int activeCars;
  final double utilizationRate;
  final double avgRevenuePerCar;

  const FleetUtilizationModel({
    required this.totalCars,
    required this.availableCars,
    required this.activeCars,
    required this.utilizationRate,
    required this.avgRevenuePerCar,
  });

  factory FleetUtilizationModel.fromJson(Map<String, dynamic> json) {
    return FleetUtilizationModel(
      totalCars: (json['totalCars'] as num?)?.toInt() ?? 0,
      availableCars: (json['availableCars'] as num?)?.toInt() ?? 0,
      activeCars: (json['activeCars'] as num?)?.toInt() ?? 0,
      utilizationRate: (json['utilizationRate'] as num?)?.toDouble() ?? 0.0,
      avgRevenuePerCar: (json['avgRevenuePerCar'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCars': totalCars,
      'availableCars': availableCars,
      'activeCars': activeCars,
      'utilizationRate': utilizationRate,
      'avgRevenuePerCar': avgRevenuePerCar,
    };
  }
}

class CustomerGrowthModel {
  final int totalRegisteredCustomers;
  final int newCustomersInRange;
  final int uniqueBookingCustomers;
  final int repeatCustomers;
  final double repeatCustomerRate;
  final double avgCustomerSpend;

  const CustomerGrowthModel({
    required this.totalRegisteredCustomers,
    required this.newCustomersInRange,
    required this.uniqueBookingCustomers,
    required this.repeatCustomers,
    required this.repeatCustomerRate,
    required this.avgCustomerSpend,
  });

  factory CustomerGrowthModel.fromJson(Map<String, dynamic> json) {
    return CustomerGrowthModel(
      totalRegisteredCustomers: (json['totalRegisteredCustomers'] as num?)?.toInt() ?? 0,
      newCustomersInRange: (json['newCustomersInRange'] as num?)?.toInt() ?? 0,
      uniqueBookingCustomers: (json['uniqueBookingCustomers'] as num?)?.toInt() ?? 0,
      repeatCustomers: (json['repeatCustomers'] as num?)?.toInt() ?? 0,
      repeatCustomerRate: (json['repeatCustomerRate'] as num?)?.toDouble() ?? 0.0,
      avgCustomerSpend: (json['avgCustomerSpend'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRegisteredCustomers': totalRegisteredCustomers,
      'newCustomersInRange': newCustomersInRange,
      'uniqueBookingCustomers': uniqueBookingCustomers,
      'repeatCustomers': repeatCustomers,
      'repeatCustomerRate': repeatCustomerRate,
      'avgCustomerSpend': avgCustomerSpend,
    };
  }
}

class AddonAdoptionModel {
  final int totalBookings;
  final int protectionCount;
  final double protectionAdoptionRate;
  final int deliveryCount;
  final double deliveryAdoptionRate;
  final int driverCount;
  final double driverAdoptionRate;
  final int couponCount;
  final double couponUsageRate;

  const AddonAdoptionModel({
    required this.totalBookings,
    required this.protectionCount,
    required this.protectionAdoptionRate,
    required this.deliveryCount,
    required this.deliveryAdoptionRate,
    required this.driverCount,
    required this.driverAdoptionRate,
    required this.couponCount,
    required this.couponUsageRate,
  });

  factory AddonAdoptionModel.fromJson(Map<String, dynamic> json) {
    return AddonAdoptionModel(
      totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
      protectionCount: (json['protectionCount'] as num?)?.toInt() ?? 0,
      protectionAdoptionRate: (json['protectionAdoptionRate'] as num?)?.toDouble() ?? 0.0,
      deliveryCount: (json['deliveryCount'] as num?)?.toInt() ?? 0,
      deliveryAdoptionRate: (json['deliveryAdoptionRate'] as num?)?.toDouble() ?? 0.0,
      driverCount: (json['driverCount'] as num?)?.toInt() ?? 0,
      driverAdoptionRate: (json['driverAdoptionRate'] as num?)?.toDouble() ?? 0.0,
      couponCount: (json['couponCount'] as num?)?.toInt() ?? 0,
      couponUsageRate: (json['couponUsageRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalBookings': totalBookings,
      'protectionCount': protectionCount,
      'protectionAdoptionRate': protectionAdoptionRate,
      'deliveryCount': deliveryCount,
      'deliveryAdoptionRate': deliveryAdoptionRate,
      'driverCount': driverCount,
      'driverAdoptionRate': driverAdoptionRate,
      'couponCount': couponCount,
      'couponUsageRate': couponUsageRate,
    };
  }
}
