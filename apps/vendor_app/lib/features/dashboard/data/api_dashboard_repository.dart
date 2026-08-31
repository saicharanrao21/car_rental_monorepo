import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/models/operations_models.dart';

class ApiDashboardRepository implements DashboardRepository {
  final ApiClient apiClient;

  ApiDashboardRepository({required this.apiClient});

  Map<String, dynamic> _normalizeBookingJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);

    // Normalize tripType from backend uppercase to client standard
    final rawTripType = copy['tripType'] as String?;
    if (rawTripType != null) {
      if (rawTripType == 'LOCAL') {
        copy['tripType'] = 'Local';
      } else if (rawTripType == 'OUTSTATION') {
        copy['tripType'] = 'Outstation';
      } else if (rawTripType == 'AIRPORT_TRANSFER') {
        copy['tripType'] = 'Airport Transfer';
      } else if (rawTripType == 'SELF_DRIVE') {
        copy['tripType'] = 'Self-Drive';
      }
    }

    // Normalize status to lowercase
    final rawStatus = copy['status'] as String?;
    if (rawStatus != null) {
      copy['status'] = rawStatus.toLowerCase();
    }

    // Convert decimal-as-string fields to double for models that expect double
    for (final field in ['totalFare', 'platformFee', 'gstAmount', 'netToVendor']) {
      if (copy[field] != null) {
        copy[field] = double.tryParse(copy[field].toString()) ?? 0.0;
      }
    }

    return copy;
  }

  Future<Response> _safeGet(String path, {dynamic fallbackData}) async {
    try {
      return await apiClient.dio.get(path).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Dashboard API partial failure: $path -> $e');
      return Response(
        requestOptions: RequestOptions(path: path),
        data: fallbackData,
        statusCode: 500,
      );
    }
  }

  @override
  Future<DashboardStats> getStats(String vendorId) async {
    final responses = await Future.wait([
      _safeGet('/vendors/me/bookings', fallbackData: []),
      _safeGet('/vendors/me/cars', fallbackData: []),
      _safeGet('/vendors/me/earnings/summary', fallbackData: {}),
    ]);

    final bookingsResponse = responses[0];
    final carsResponse = responses[1];
    final earningsResponse = responses[2];

    // 1. Bookings calculation
    final List<dynamic> bookingsData = bookingsResponse.data is List
        ? bookingsResponse.data
        : (bookingsResponse.data['data'] ?? []);
    final referenceToday = DateTime.now();
    int todaysBookings = 0;
    int pendingRequests = 0;

    for (final b in bookingsData) {
      final status = (b['status'] as String?)?.toLowerCase();
      final startDateStr = b['startDate'] as String?;
      if (startDateStr != null) {
        final startDate = DateTime.tryParse(startDateStr);
        if (startDate != null) {
          final isSameDay = startDate.year == referenceToday.year &&
              startDate.month == referenceToday.month &&
              startDate.day == referenceToday.day;
          final isOngoingOrConfirmed =
              status == 'ongoing' || status == 'confirmed' || status == 'handover_ready';
          if (isSameDay && isOngoingOrConfirmed) {
            todaysBookings++;
          }
        }
      }
      if (status == 'pending') {
        pendingRequests++;
      }
    }

    // 2. Cars calculation
    final List<dynamic> carsData = carsResponse.data is List
        ? carsResponse.data
        : (carsResponse.data['data'] ?? []);
    int activeCars = 0;
    int inactiveCars = 0;
    for (final c in carsData) {
      final isAvailable = c['isAvailable'] as bool? ?? false;
      if (isAvailable) {
        activeCars++;
      } else {
        inactiveCars++;
      }
    }

    // 3. Earnings calculation
    final earningsData = earningsResponse.data;
    final thisMonthEarnings =
        double.tryParse(earningsData['thisMonthEarnings']?.toString() ?? '0.0') ?? 0.0;

    return DashboardStats(
      todaysBookings: todaysBookings,
      pendingRequests: pendingRequests,
      thisMonthEarnings: thisMonthEarnings,
      activeCars: activeCars,
      inactiveCars: inactiveCars,
    );
  }

  @override
  Future<List<BookingModel>> getLatestBookingRequests(String vendorId, {int limit = 3}) async {
    final response = await apiClient.dio.get(
      '/vendors/me/bookings',
      queryParameters: {
        'status': 'PENDING',
      },
    );
    final List<dynamic> bookingsData =
        response.data is List ? response.data : (response.data['data'] ?? []);
    final bookings = bookingsData.map((b) {
      final normalized = _normalizeBookingJson(Map<String, dynamic>.from(b));
      return BookingModel.fromJson(normalized);
    }).toList();

    bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookings.take(limit).toList();
  }

  @override
  Future<void> respondToBooking(String bookingId, bool accept) async {
    await apiClient.dio.patch(
      '/bookings/$bookingId/status',
      data: {
        'status': accept ? 'CONFIRMED' : 'CANCELLED',
      },
    );
  }

  @override
  Future<List<TriageItem>> getOperationsTriage(String vendorId) async {
    final responses = await Future.wait([
      _safeGet('/vendors/me/bookings', fallbackData: []),
      _safeGet('/vendors/me/cars', fallbackData: []),
      _safeGet('/vendors/me/earnings/summary', fallbackData: {}),
      _safeGet('/vendors/me/documents', fallbackData: []),
    ]);

    final List<dynamic> bookingsData = responses[0].data is List
        ? responses[0].data
        : (responses[0].data['data'] ?? []);
    final List<dynamic> carsData = responses[1].data is List
        ? responses[1].data
        : (responses[1].data['data'] ?? []);
    final earningsData = responses[2].data;
    final List<dynamic> docsData = responses[3].data is List
        ? responses[3].data
        : (responses[3].data['data'] ?? []);

    final List<TriageItem> items = [];
    final now = DateTime.now();

    // 1. Pending bookings triage (URGENT)
    for (final b in bookingsData) {
      final status = (b['status'] as String?)?.toLowerCase();
      final id = b['id']?.toString() ?? '';
      final car = b['car'];
      final carName = car != null ? '${car['make'] ?? ''} ${car['model'] ?? ''}'.trim() : 'Vehicle';
      final totalFare = b['totalFare']?.toString() ?? '0';

      if (status == 'pending') {
        items.add(TriageItem(
          id: 'pending_$id',
          title: 'Booking confirmation required',
          subtitle: '₹$totalFare • $carName requested',
          priority: TriagePriority.urgent,
          badgeText: 'PENDING ACTION',
          actionLabel: 'Review Request',
          routePath: '/bookings/$id',
          vehicleName: carName,
          bookingId: id,
          isBookingAction: true,
        ));
      }
    }

    // 2. Pickups and Returns due today (HIGH / TODAY)
    for (final b in bookingsData) {
      final status = (b['status'] as String?)?.toLowerCase();
      final id = b['id']?.toString() ?? '';
      final car = b['car'];
      final carName = car != null ? '${car['make'] ?? ''} ${car['model'] ?? ''}'.trim() : 'Vehicle';
      final startDateStr = b['startDate'] as String?;
      final endDateStr = b['endDate'] as String?;
      final pickupLoc = b['pickupLocation'] ?? 'Hub';

      if (startDateStr != null && (status == 'confirmed' || status == 'handover_ready')) {
        final startDate = DateTime.tryParse(startDateStr);
        if (startDate != null &&
            startDate.year == now.year &&
            startDate.month == now.month &&
            startDate.day == now.day) {
          final timeStr = DateFormat('hh:mm a').format(startDate);
          final diffMinutes = startDate.difference(now).inMinutes;
          final isApproaching = diffMinutes > 0 && diffMinutes <= 120;

          items.add(TriageItem(
            id: 'pickup_$id',
            title: isApproaching ? 'Pickup in $diffMinutes min ($timeStr)' : 'Pickup scheduled today at $timeStr',
            subtitle: '$carName • $pickupLoc',
            priority: isApproaching ? TriagePriority.urgent : TriagePriority.high,
            badgeText: isApproaching ? 'HANDOVER DUE' : 'TODAY PICKUP',
            actionLabel: 'Prepare Handover',
            routePath: '/bookings/$id',
            vehicleName: carName,
            timestamp: startDate,
            bookingId: id,
          ));
        }
      }

      if (endDateStr != null && (status == 'ongoing' || status == 'return_pending')) {
        final endDate = DateTime.tryParse(endDateStr);
        if (endDate != null &&
            endDate.year == now.year &&
            endDate.month == now.month &&
            endDate.day == now.day) {
          final timeStr = DateFormat('hh:mm a').format(endDate);
          items.add(TriageItem(
            id: 'return_$id',
            title: 'Vehicle return due today at $timeStr',
            subtitle: '$carName • Complete return inspection',
            priority: TriagePriority.high,
            badgeText: 'RETURN DUE',
            actionLabel: 'Inspect Return',
            routePath: '/bookings/$id',
            vehicleName: carName,
            timestamp: endDate,
            bookingId: id,
          ));
        }
      }
    }

    // 3. Expiring Documents (TODAY / HIGH)
    for (final d in docsData) {
      final docType = d['type']?.toString() ?? 'Document';
      final expiresAtStr = d['expiresAt'] as String?;
      if (expiresAtStr != null) {
        final expiresAt = DateTime.tryParse(expiresAtStr);
        if (expiresAt != null) {
          final daysLeft = expiresAt.difference(now).inDays;
          if (daysLeft >= 0 && daysLeft <= 14) {
            items.add(TriageItem(
              id: 'doc_${d['id'] ?? docType}',
              title: '$docType expiring in $daysLeft days',
              subtitle: 'Renew document before expiry to maintain fleet compliance',
              priority: daysLeft <= 3 ? TriagePriority.urgent : TriagePriority.today,
              badgeText: 'COMPLIANCE',
              actionLabel: 'Update Document',
              routePath: '/profile',
            ));
          }
        }
      }
    }

    // 4. Unavailable cars (INFORMATIONAL)
    int unavailableCount = 0;
    for (final c in carsData) {
      if ((c['isAvailable'] as bool?) == false) {
        unavailableCount++;
      }
    }
    if (unavailableCount > 0) {
      items.add(TriageItem(
        id: 'fleet_unavailable',
        title: '$unavailableCount vehicle${unavailableCount > 1 ? 's' : ''} currently offline',
        subtitle: 'Vehicles marked unavailable will not appear in customer searches',
        priority: TriagePriority.informational,
        badgeText: 'FLEET STATUS',
        actionLabel: 'View Fleet',
        routePath: '/fleet',
      ));
    }

    // 5. Held earnings / settlement (INFORMATIONAL)
    final heldEarnings = double.tryParse(earningsData['heldEarnings']?.toString() ?? '0.0') ?? 0.0;
    if (heldEarnings > 0) {
      items.add(TriageItem(
        id: 'earnings_held',
        title: '₹${heldEarnings.toStringAsFixed(0)} pending settlement hold',
        subtitle: 'Settlement clears 48 hours post completed trip verification',
        priority: TriagePriority.informational,
        badgeText: 'FINANCIAL',
        actionLabel: 'View Ledger',
        routePath: '/earnings',
      ));
    }

    // Sort items by priority
    items.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return items;
  }

  @override
  Future<List<TodayTimelineItem>> getTodayOperations(String vendorId) async {
    final response = await _safeGet('/vendors/me/bookings', fallbackData: []);
    final List<dynamic> bookingsData =
        response.data is List ? response.data : (response.data['data'] ?? []);

    final now = DateTime.now();
    final List<TodayTimelineItem> timeline = [];

    for (final b in bookingsData) {
      final id = b['id']?.toString() ?? '';
      final status = (b['status'] as String?)?.toLowerCase() ?? '';
      final tripType = b['tripType']?.toString() ?? 'Self-Drive';
      final car = b['car'];
      final carName = car != null ? '${car['make'] ?? ''} ${car['model'] ?? ''}'.trim() : 'Vehicle';
      final regNo = car?['registrationNumber']?.toString();
      final customer = b['customer'];
      final customerName = customer?['name']?.toString() ?? 'Customer';
      // Customer-safe display (masked last name)
      final nameParts = customerName.split(' ');
      final safeName = nameParts.length > 1
          ? '${nameParts[0]} ${nameParts[1][0]}.'
          : customerName;

      final pickupLoc = b['pickupLocation']?.toString() ?? 'Hub';
      final dropLoc = b['dropLocation']?.toString() ?? pickupLoc;

      final startDateStr = b['startDate'] as String?;
      final endDateStr = b['endDate'] as String?;

      if (startDateStr != null) {
        final startDate = DateTime.tryParse(startDateStr);
        if (startDate != null &&
            startDate.year == now.year &&
            startDate.month == now.month &&
            startDate.day == now.day) {
          timeline.add(TodayTimelineItem(
            id: 'timeline_pickup_$id',
            bookingId: id,
            type: TimelineEventType.pickup,
            time: startDate,
            vehicleName: carName,
            registrationNumber: regNo,
            customerSafeName: safeName,
            hubLocation: pickupLoc,
            status: status.toUpperCase(),
            tripType: tripType,
          ));
        }
      }

      if (endDateStr != null) {
        final endDate = DateTime.tryParse(endDateStr);
        if (endDate != null &&
            endDate.year == now.year &&
            endDate.month == now.month &&
            endDate.day == now.day) {
          timeline.add(TodayTimelineItem(
            id: 'timeline_return_$id',
            bookingId: id,
            type: TimelineEventType.vehicleReturn,
            time: endDate,
            vehicleName: carName,
            registrationNumber: regNo,
            customerSafeName: safeName,
            hubLocation: dropLoc,
            status: status.toUpperCase(),
            tripType: tripType,
          ));
        }
      }
    }

    timeline.sort((a, b) => a.time.compareTo(b.time));
    return timeline;
  }

  @override
  Future<BookingMatrix> getBookingMatrix(String vendorId) async {
    final response = await _safeGet('/vendors/me/bookings', fallbackData: []);
    final List<dynamic> bookingsData =
        response.data is List ? response.data : (response.data['data'] ?? []);

    final now = DateTime.now();
    int todayCount = 0;
    int pendingCount = 0;
    int upcomingCount = 0;
    int completedCount = 0;
    int activeCount = 0;

    for (final b in bookingsData) {
      final status = (b['status'] as String?)?.toLowerCase();
      final startDateStr = b['startDate'] as String?;
      final startDate = startDateStr != null ? DateTime.tryParse(startDateStr) : null;

      if (status == 'pending') {
        pendingCount++;
      } else if (status == 'ongoing' || status == 'handover_ready' || status == 'return_pending') {
        activeCount++;
      } else if (status == 'completed') {
        completedCount++;
      }

      if (startDate != null) {
        final isToday = startDate.year == now.year &&
            startDate.month == now.month &&
            startDate.day == now.day;
        if (isToday && (status == 'confirmed' || status == 'ongoing' || status == 'handover_ready')) {
          todayCount++;
        } else if (startDate.isAfter(now) && status == 'confirmed') {
          upcomingCount++;
        }
      }
    }

    return BookingMatrix(
      todayCount: todayCount,
      pendingCount: pendingCount,
      upcomingCount: upcomingCount,
      completedCount: completedCount,
      activeCount: activeCount,
    );
  }

  @override
  Future<FleetSummary> getFleetSummary(String vendorId) async {
    final response = await _safeGet('/vendors/me/cars', fallbackData: []);
    final List<dynamic> carsData =
        response.data is List ? response.data : (response.data['data'] ?? []);

    int total = carsData.length;
    int available = 0;
    int unavailable = 0;
    int onTrip = 0;

    for (final c in carsData) {
      final isAvail = c['isAvailable'] as bool? ?? false;
      final currentBooking = c['currentBooking'];
      if (currentBooking != null) {
        onTrip++;
      } else if (isAvail) {
        available++;
      } else {
        unavailable++;
      }
    }

    return FleetSummary(
      totalCars: total,
      availableCars: available,
      onTripCars: onTrip,
      unavailableCars: unavailable,
    );
  }

  @override
  Future<EarningsSnapshot> getEarningsSnapshot(String vendorId) async {
    final response = await _safeGet('/vendors/me/earnings/summary', fallbackData: {});
    final data = response.data is Map ? response.data : {};

    return EarningsSnapshot(
      thisMonthEarnings: double.tryParse(data['thisMonthEarnings']?.toString() ?? '0.0') ?? 0.0,
      availableBalance: double.tryParse(data['availableBalance']?.toString() ?? '0.0') ?? 0.0,
      heldEarnings: double.tryParse(data['heldEarnings']?.toString() ?? '0.0') ?? 0.0,
      totalEarnings: double.tryParse(data['totalEarnings']?.toString() ?? '0.0') ?? 0.0,
      totalPaidOut: double.tryParse(data['totalPaidOut']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

