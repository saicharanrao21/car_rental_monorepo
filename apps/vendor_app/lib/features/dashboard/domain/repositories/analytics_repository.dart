import 'package:core/core.dart';

class VendorAnalyticsModel {
  final int totalViews;
  final int wishlistCount;
  final int confirmedBookings;
  final double conversionRate;
  final List<CarViewsItem> viewsByCarLast30Days;

  VendorAnalyticsModel({
    required this.totalViews,
    required this.wishlistCount,
    required this.confirmedBookings,
    required this.conversionRate,
    required this.viewsByCarLast30Days,
  });

  factory VendorAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final list = json['viewsByCarLast30Days'] as List? ?? [];
    return VendorAnalyticsModel(
      totalViews: json['totalViews'] ?? 0,
      wishlistCount: json['wishlistCount'] ?? 0,
      confirmedBookings: json['confirmedBookings'] ?? 0,
      conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 0.0,
      viewsByCarLast30Days: list.map((item) => CarViewsItem.fromJson(Map<String, dynamic>.from(item))).toList(),
    );
  }
}

class CarViewsItem {
  final String carId;
  final String carName;
  final int views;

  CarViewsItem({
    required this.carId,
    required this.carName,
    required this.views,
  });

  factory CarViewsItem.fromJson(Map<String, dynamic> json) {
    return CarViewsItem(
      carId: json['carId'] ?? '',
      carName: json['carName'] ?? 'Car',
      views: json['views'] ?? 0,
    );
  }
}

abstract class AnalyticsRepository {
  Future<VendorAnalyticsModel> getVendorAnalytics();
}

class ApiAnalyticsRepository implements AnalyticsRepository {
  final ApiClient apiClient;

  ApiAnalyticsRepository({required this.apiClient});

  @override
  Future<VendorAnalyticsModel> getVendorAnalytics() async {
    final response = await apiClient.dio.get('/vendors/me/analytics');
    return VendorAnalyticsModel.fromJson(Map<String, dynamic>.from(response.data));
  }
}
