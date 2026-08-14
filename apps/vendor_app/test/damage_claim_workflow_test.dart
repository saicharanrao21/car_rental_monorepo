import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/bookings/data/mock_vendor_bookings_repository.dart';

void main() {
  group('Vendor Damage Claim Workflow Tests', () {
    late MockVendorBookingsRepository repo;

    setUp(() {
      repo = MockVendorBookingsRepository();
    });

    test('submitDamageClaim stores and retrieves damage claim successfully', () async {
      final claim = await repo.submitDamageClaim(
        'b_completed_1',
        claimedAmount: 4500.0,
        description: 'Rear bumper scratch and dent after trip return',
        damagePhotos: ['damage-claim/photo_1.jpg', 'damage-claim/photo_2.jpg'],
        vendorNotes: 'Customer acknowledged incident during return handover',
      );

      expect(claim.bookingId, 'b_completed_1');
      expect(claim.claimedAmount, 4500.0);
      expect(claim.status, DamageClaimStatus.SUBMITTED);
      expect(claim.damagePhotos, hasLength(2));
      expect(claim.description, contains('Rear bumper scratch'));

      final retrieved = await repo.getDamageClaims('b_completed_1');
      expect(retrieved, hasLength(1));
      expect(retrieved.first.id, claim.id);
      expect(retrieved.first.claimedAmount, 4500.0);
    });

    test('DamageClaimStatus parsing handles all enum values correctly', () {
      expect(DamageClaimStatus.fromString('SUBMITTED'), DamageClaimStatus.SUBMITTED);
      expect(DamageClaimStatus.fromString('UNDER_REVIEW'), DamageClaimStatus.UNDER_REVIEW);
      expect(DamageClaimStatus.fromString('APPROVED'), DamageClaimStatus.APPROVED);
      expect(DamageClaimStatus.fromString('PARTIALLY_APPROVED'), DamageClaimStatus.PARTIALLY_APPROVED);
      expect(DamageClaimStatus.fromString('REJECTED'), DamageClaimStatus.REJECTED);
      expect(DamageClaimStatus.fromString('SETTLED'), DamageClaimStatus.SETTLED);
      expect(DamageClaimStatus.fromString(null), DamageClaimStatus.SUBMITTED);
    });
  });
}
