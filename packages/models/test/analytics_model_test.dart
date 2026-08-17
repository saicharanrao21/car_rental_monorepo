import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('Analytics Models Test Suite', () {
    test('RevenueSummaryModel JSON serialization & deserialization', () {
      final json = {
        'grossBookingValue': 10000.0,
        'platformRevenue': 1000.0,
        'vendorPayouts': 8000.0,
        'gstCollected': 1800.0,
        'baseFareRevenue': 7500.0,
        'protectionRevenue': 800.0,
        'deliveryRevenue': 400.0,
        'discountTotal': 250.0,
        'refundTotal': 500.0,
        'netPlatformRevenue': 1950.0,
        'walletLiability': 15000.0,
        'loyaltyLiability': 2500.0,
        'referralCost': 500.0,
      };

      final model = RevenueSummaryModel.fromJson(json);
      expect(model.grossBookingValue, 10000.0);
      expect(model.platformRevenue, 1000.0);
      expect(model.netPlatformRevenue, 1950.0);
      expect(model.walletLiability, 15000.0);
      expect(model.loyaltyLiability, 2500.0);

      final outJson = model.toJson();
      expect(outJson['grossBookingValue'], 10000.0);
      expect(outJson['loyaltyLiability'], 2500.0);
    });

    test('BookingLifecycleStatsModel JSON serialization & deserialization', () {
      final json = {
        'totalBookings': 10,
        'completedBookings': 7,
        'cancelledBookings': 2,
        'confirmedBookings': 1,
        'ongoingBookings': 0,
        'pendingBookings': 0,
        'completionRate': 70.0,
        'cancellationRate': 20.0,
        'averageBookingValue': 3500.0,
        'averageDurationDays': 2.5,
        'statusDistribution': {
          'COMPLETED': 7,
          'CANCELLED': 2,
          'CONFIRMED': 1,
        },
      };

      final model = BookingLifecycleStatsModel.fromJson(json);
      expect(model.totalBookings, 10);
      expect(model.completionRate, 70.0);
      expect(model.statusDistribution['COMPLETED'], 7);

      final outJson = model.toJson();
      expect(outJson['completionRate'], 70.0);
      expect((outJson['statusDistribution'] as Map)['CANCELLED'], 2);
    });

    test('FleetUtilizationModel JSON serialization & deserialization', () {
      final json = {
        'totalCars': 50,
        'availableCars': 35,
        'activeCars': 15,
        'utilizationRate': 30.0,
        'avgRevenuePerCar': 4500.0,
      };

      final model = FleetUtilizationModel.fromJson(json);
      expect(model.totalCars, 50);
      expect(model.utilizationRate, 30.0);

      final outJson = model.toJson();
      expect(outJson['utilizationRate'], 30.0);
    });

    test('CustomerGrowthModel JSON serialization & deserialization', () {
      final json = {
        'totalRegisteredCustomers': 200,
        'newCustomersInRange': 40,
        'uniqueBookingCustomers': 60,
        'repeatCustomers': 25,
        'repeatCustomerRate': 41.7,
        'avgCustomerSpend': 5200.0,
      };

      final model = CustomerGrowthModel.fromJson(json);
      expect(model.totalRegisteredCustomers, 200);
      expect(model.repeatCustomerRate, 41.7);

      final outJson = model.toJson();
      expect(outJson['repeatCustomerRate'], 41.7);
    });

    test('AddonAdoptionModel JSON serialization & deserialization', () {
      final json = {
        'totalBookings': 100,
        'protectionCount': 45,
        'protectionAdoptionRate': 45.0,
        'deliveryCount': 30,
        'deliveryAdoptionRate': 30.0,
        'driverCount': 15,
        'driverAdoptionRate': 15.0,
        'couponCount': 20,
        'couponUsageRate': 20.0,
      };

      final model = AddonAdoptionModel.fromJson(json);
      expect(model.totalBookings, 100);
      expect(model.protectionAdoptionRate, 45.0);
      expect(model.couponUsageRate, 20.0);

      final outJson = model.toJson();
      expect(outJson['protectionAdoptionRate'], 45.0);
    });
  });
}
