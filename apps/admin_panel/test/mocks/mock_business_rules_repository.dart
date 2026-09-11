import 'package:admin_panel/features/business_rules/domain/models/system_config_detail.dart';
import 'package:admin_panel/features/business_rules/domain/models/config_audit_item.dart';
import 'package:admin_panel/features/business_rules/domain/repositories/business_rules_repository.dart';

class MockBusinessRulesRepository implements BusinessRulesRepository {
  final Map<String, SystemConfigDetail> _store = {};
  final List<ConfigAuditItem> _auditLogs = [];

  MockBusinessRulesRepository() {
    _seedDefaultConfigs();
  }

  void _seedDefaultConfigs() {
    _store['pricing.tax'] = const SystemConfigDetail(
      key: 'pricing.tax',
      effectiveValue: {'gstRate': 18},
      source: 'DEFAULT_FALLBACK',
      isExplicitlyConfigured: false,
      version: 1,
      category: 'PRICING',
      description: 'Goods and Services Tax (GST) rate percentage applied to platform service fees',
      isPublic: true,
    );

    _store['pricing.quote'] = const SystemConfigDetail(
      key: 'pricing.quote',
      effectiveValue: {'validityMinutes': 15},
      source: 'DEFAULT_FALLBACK',
      isExplicitlyConfigured: false,
      version: 1,
      category: 'PRICING',
      description: 'Booking quote validity window duration in minutes before expiration',
      isPublic: true,
    );

    _store['pricing.duration_discounts'] = const SystemConfigDetail(
      key: 'pricing.duration_discounts',
      effectiveValue: [
        {'minDays': 7, 'discountPercent': 10},
        {'minDays': 30, 'discountPercent': 20},
      ],
      source: 'DEFAULT_FALLBACK',
      isExplicitlyConfigured: false,
      version: 1,
      category: 'PRICING',
      description: 'Ordered multi-day duration discount tiers based on rental duration in days',
      isPublic: true,
    );

    _store['booking.cancellation_matrix'] = const SystemConfigDetail(
      key: 'booking.cancellation_matrix',
      effectiveValue: {
        'tiers': [
          {
            'minHoursBeforePickup': 24,
            'feePercent': 0,
            'tier': 'FULL_REFUND_FREE_CANCELLATION',
            'description': 'Free cancellation (> 24 hours before pickup)',
          },
          {
            'minHoursBeforePickup': 6,
            'feePercent': 25,
            'tier': 'MODERATE_CANCELLATION',
            'description': 'Cancellation between 6 and 24 hours before pickup (25% fee)',
          },
          {
            'minHoursBeforePickup': 0,
            'feePercent': 50,
            'tier': 'LATE_CANCELLATION',
            'description': 'Cancellation within 6 hours of pickup time (50% fee)',
          },
        ],
        'afterStartFeePercent': 100,
        'afterStartTier': 'NO_REFUND_AFTER_START',
        'afterStartDescription': 'Cancellation after trip pickup time (Non-refundable)',
      },
      source: 'DEFAULT_FALLBACK',
      isExplicitlyConfigured: false,
      version: 1,
      category: 'BOOKING',
      description: 'Time-based cancellation fee percentage tiers and after-start fee policy',
      isPublic: true,
    );

    _store['pricing.commission'] = const SystemConfigDetail(
      key: 'pricing.commission',
      effectiveValue: {'defaultPercent': 10},
      source: 'DEFAULT_FALLBACK',
      isExplicitlyConfigured: false,
      version: 1,
      category: 'PRICING',
      description: 'Default platform commission percentage fallback when no granular rule matches',
      isPublic: false,
    );

    _store['deposits.defaults'] = const SystemConfigDetail(
      key: 'deposits.defaults',
      effectiveValue: {
        'HATCHBACK': 3000,
        'SEDAN': 4000,
        'SUV': 5000,
        'LUXURY': 10000,
        'TEMPO_TRAVELLER': 8000,
        'MINI_BUS': 10000,
      },
      source: 'DEFAULT_FALLBACK',
      isExplicitlyConfigured: false,
      version: 1,
      category: 'FINANCE',
      description: 'Default security deposit amount in INR per car category',
      isPublic: true,
    );

    _store['wallet.rules'] = const SystemConfigDetail(
      key: 'wallet.rules',
      effectiveValue: {
        'maxSingleDeposit': 50000,
        'minSingleDeposit': 100,
        'maxWalletBalanceCap': 100000,
        'maxWalletPaymentPercentage': 100,
        'minBookingAmountForWalletUse': 0,
        'maxPromoCreditPerBooking': 5000,
        'maxDailyWalletUsage': 50000,
        'isDepositsEnabled': true,
      },
      source: 'DEFAULT_FALLBACK',
      isExplicitlyConfigured: false,
      version: 1,
      category: 'WALLET',
      description: 'Wallet deposit limits, checkout usage caps, and promotional credit bounds',
      isPublic: true,
    );

    _store['search.ranking'] = const SystemConfigDetail(
      key: 'search.ranking',
      effectiveValue: {
        'relevanceWeight': 0.35,
        'distanceWeight': 0.35,
        'ratingWeight': 0.20,
        'availabilityWeight': 0.10,
        'sponsoredBoostMultiplier': 1.25,
        'featuredBoostMultiplier': 1.15,
      },
      source: 'DEFAULT_FALLBACK',
      isExplicitlyConfigured: false,
      version: 1,
      category: 'SEARCH',
      description: 'Multi-variable ranking algorithm weights and sponsored placement multipliers',
      isPublic: false,
    );

    _store['booking.policies'] = const SystemConfigDetail(
      key: 'booking.policies',
      effectiveValue: {
        'handoverOtpTtlMinutes': 15,
        'cancellationGraceMinutes': 60,
        'maxAdvanceBookingDays': 90,
        'doorstepDeliveryMaxRadiusKm': 50,
      },
      source: 'DEFAULT_FALLBACK',
      isExplicitlyConfigured: false,
      version: 1,
      category: 'BOOKING',
      description: 'Operational booking constraints and time limits',
      isPublic: true,
    );
  }

  @override
  Future<List<SystemConfigDetail>> getAllConfigs() async {
    return _store.values.toList();
  }

  @override
  Future<SystemConfigDetail> getConfigDetail(String key) async {
    final item = _store[key];
    if (item == null) {
      throw Exception('Configuration key [$key] not found.');
    }
    return item;
  }

  @override
  Future<List<ConfigAuditItem>> getAuditHistory(String key, {int limit = 50}) async {
    return _auditLogs
        .where((l) => l.key == key)
        .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<void> updateConfig({
    required String key,
    required dynamic value,
    int? expectedVersion,
    String? reason,
  }) async {
    final existing = _store[key];
    if (existing == null) {
      throw Exception('Configuration key [$key] not found.');
    }

    // Optimistic Concurrency Control
    if (expectedVersion != null && expectedVersion != existing.version) {
      throw ConcurrencyConflictException(
        key: key,
        expectedVersion: expectedVersion,
        currentServerVersion: existing.version,
        serverValue: existing.effectiveValue,
        message:
            'Configuration [$key] has been modified by another administrator (version mismatch: expected v$expectedVersion, server is v${existing.version}).',
      );
    }

    final newVersion = existing.version + 1;
    final previousValue = existing.effectiveValue;

    final updated = existing.copyWith(
      effectiveValue: value,
      source: 'DATABASE',
      isExplicitlyConfigured: true,
      version: newVersion,
      updatedAt: DateTime.now(),
      updatedBy: 'admin_test_user',
    );

    _store[key] = updated;

    _auditLogs.insert(
      0,
      ConfigAuditItem(
        id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
        action: 'CONFIG_UPDATED',
        key: key,
        previousValue: previousValue,
        newValue: value,
        adminUserId: 'admin_test_user',
        adminUser: {'name': 'Super Admin', 'email': 'admin@drivego.in', 'role': 'ADMIN'},
        version: newVersion,
        reason: reason,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> batchUpdateConfigs({
    required List<BatchConfigItem> items,
    String? reason,
  }) async {
    // 1. OCC check on all items
    for (final item in items) {
      final existing = _store[item.key];
      if (existing != null && item.expectedVersion != null && item.expectedVersion != existing.version) {
        throw ConcurrencyConflictException(
          key: item.key,
          expectedVersion: item.expectedVersion!,
          currentServerVersion: existing.version,
          serverValue: existing.effectiveValue,
          message: 'Batch aborted: Concurrency conflict on [${item.key}].',
        );
      }
    }

    // 2. Apply all updates
    for (final item in items) {
      await updateConfig(
        key: item.key,
        value: item.value,
        expectedVersion: item.expectedVersion,
        reason: reason ?? 'Batch update',
      );
    }
  }
}
