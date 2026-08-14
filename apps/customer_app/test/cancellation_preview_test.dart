import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/features/my_bookings/domain/repositories/my_bookings_repository.dart';

void main() {
  test('CancellationPreviewModel parses json correctly', () {
    final json = {
      'bookingId': 'booking_test_123',
      'tier': 'MODERATE_CANCELLATION',
      'tierDescription': 'Cancellation between 6 and 24 hours before pickup (25% fee)',
      'startDate': '2026-08-20T12:00:00.000Z',
      'hoursRemaining': 14.5,
      'amountPaid': '5000.00',
      'cancellationFeePercent': 25,
      'cancellationFee': '1250.00',
      'refundAmountPercent': 75,
      'refundAmount': '3750.00',
      'currency': 'INR',
      'isEligibleForRefund': true,
    };

    final model = CancellationPreviewModel.fromJson(json);

    expect(model.bookingId, 'booking_test_123');
    expect(model.tier, 'MODERATE_CANCELLATION');
    expect(model.hoursRemaining, 14.5);
    expect(model.amountPaid, 5000.0);
    expect(model.cancellationFeePercent, 25);
    expect(model.cancellationFee, 1250.0);
    expect(model.refundAmountPercent, 75);
    expect(model.refundAmount, 3750.0);
    expect(model.currency, 'INR');
    expect(model.isEligibleForRefund, true);
  });
}
