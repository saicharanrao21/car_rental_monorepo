import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/revenue_repository.dart';

class ApiRevenueRepository implements RevenueRepository {
  final ApiClient _apiClient;

  ApiRevenueRepository(this._apiClient);

  String _formatDate(DateTime dt) {
    return dt.toIso8601String().split('T')[0];
  }

  @override
  Future<RevenueSummary> getSummary(DateTimeRange range) async {
    final response = await _apiClient.dio.get(
      '/admin/revenue/summary',
      queryParameters: {
        'startDate': _formatDate(range.start),
        'endDate': _formatDate(range.end),
      },
    );

    final data = response.data;
    return RevenueSummary(
      grossBookingValue: (data['grossBookingValue'] ?? 0).toDouble(),
      platformRevenue: (data['platformRevenue'] ?? 0).toDouble(),
      vendorPayouts: (data['vendorPayouts'] ?? 0).toDouble(),
      gstCollected: (data['gstCollected'] ?? 0).toDouble(),
    );
  }

  @override
  Future<List<double>> getRevenueOverTime(DateTimeRange range) async {
    final response = await _apiClient.dio.get(
      '/admin/revenue/over-time',
      queryParameters: {
        'startDate': _formatDate(range.start),
        'endDate': _formatDate(range.end),
      },
    );

    final data = response.data as List;
    return data.map<double>((item) => (item['amount'] ?? 0).toDouble()).toList();
  }

  @override
  Future<Map<String, double>> getBookingsByCity(DateTimeRange range) async {
    final response = await _apiClient.dio.get(
      '/admin/revenue/by-city',
      queryParameters: {
        'startDate': _formatDate(range.start),
        'endDate': _formatDate(range.end),
      },
    );

    final data = response.data as List;
    final map = <String, double>{};
    for (final item in data) {
      final city = item['city'] as String;
      final totalFare = (item['totalFare'] ?? 0).toDouble();
      map[city] = totalFare;
    }
    return map;
  }

  @override
  Future<Map<String, int>> getBookingsByTripType(DateTimeRange range) async {
    final response = await _apiClient.dio.get(
      '/admin/revenue/by-trip-type',
      queryParameters: {
        'startDate': _formatDate(range.start),
        'endDate': _formatDate(range.end),
      },
    );

    final data = response.data as List;
    final map = <String, int>{};
    for (final item in data) {
      final tripType = item['tripType'] as String;
      final count = (item['count'] ?? 0) as int;
      map[tripType] = count;
    }
    return map;
  }

  @override
  Future<List<VendorModel>> getTopVendorsByRevenue({int limit = 10}) async {
    final response = await _apiClient.dio.get(
      '/admin/revenue/top-vendors',
      queryParameters: {'limit': limit},
    );

    final data = response.data as List;
    return data.map((item) {
      return VendorModel(
        id: item['vendorId'] ?? '',
        businessName: item['businessName'] ?? 'Unknown',
        ownerName: item['ownerName'] ?? 'Unknown',
        city: item['city'] ?? 'Unknown',
        businessType: 'INDIVIDUAL',
        verificationStatus: 'VERIFIED',
      );
    }).toList();
  }
}
