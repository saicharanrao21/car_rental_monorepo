class FareCalculatorResult {
  final double baseFare;
  final double platformFee;
  final double gst;
  final double total;
  final double netToVendor;

  const FareCalculatorResult({
    required this.baseFare,
    required this.platformFee,
    required this.gst,
    required this.total,
    required this.netToVendor,
  });

  @override
  String toString() {
    return 'FareCalculatorResult(baseFare: $baseFare, platformFee: $platformFee, gst: $gst, total: $total, netToVendor: $netToVendor)';
  }
}

class FareCalculatorService {
  /// Calculates the fare components based on distance, package base price, price per km, and commission percent.
  /// Handles both percentage (e.g., 10.0 for 10%) and fractional (e.g., 0.10 for 10%) values for commissionPercent.
  static FareCalculatorResult calculateFare({
    required double distanceKm,
    required double basePackagePrice,
    required double pricePerKm,
    required double commissionPercent,
  }) {
    final baseFare = (distanceKm * pricePerKm) + basePackagePrice;
    
    // Convert percentage (e.g. 10.0) to fractional form (0.10) if necessary.
    final effectiveCommissionFraction = commissionPercent > 1.0 
        ? commissionPercent / 100.0 
        : commissionPercent;

    final platformFee = baseFare * effectiveCommissionFraction;
    final gst = platformFee * 0.18;
    final total = baseFare + platformFee + gst;
    final netToVendor = baseFare;

    return FareCalculatorResult(
      baseFare: baseFare,
      platformFee: platformFee,
      gst: gst,
      total: total,
      netToVendor: netToVendor,
    );
  }
}
