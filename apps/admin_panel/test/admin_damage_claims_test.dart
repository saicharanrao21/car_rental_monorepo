import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('Admin Damage Claims Adjudication Tests', () {
    test('parses damage claim list from API response format correctly', () {
      final json = {
        'id': 'claim_admin_1',
        'bookingId': 'book_999',
        'vendorId': 'v_123',
        'claimedAmount': 6000.0,
        'approvedAmount': 4000.0,
        'status': 'PARTIALLY_APPROVED',
        'description': 'Front bumper dent and cracked headlight assembly',
        'damagePhotos': [
          'https://signed.r2.dev/damage/photo1.jpg',
          'https://signed.r2.dev/damage/photo2.jpg',
        ],
        'adminNotes': 'Approved partial ₹4,000 deduction after verifying pre-trip photos.',
        'createdAt': '2026-08-14T12:00:00Z',
        'resolvedAt': '2026-08-14T15:30:00Z',
      };

      final claim = DamageClaimModel.fromJson(json);

      expect(claim.id, 'claim_admin_1');
      expect(claim.bookingId, 'book_999');
      expect(claim.claimedAmount, 6000.0);
      expect(claim.approvedAmount, 4000.0);
      expect(claim.status, DamageClaimStatus.PARTIALLY_APPROVED);
      expect(claim.damagePhotos, hasLength(2));
      expect(claim.adminNotes, contains('Approved partial'));
      expect(claim.resolvedAt, isNotNull);
    });

    test('validates adjudication decision types and status mapping', () {
      expect(DamageClaimStatus.fromString('APPROVED'), DamageClaimStatus.APPROVED);
      expect(DamageClaimStatus.fromString('PARTIALLY_APPROVED'), DamageClaimStatus.PARTIALLY_APPROVED);
      expect(DamageClaimStatus.fromString('REJECTED'), DamageClaimStatus.REJECTED);
      expect(DamageClaimStatus.fromString('SUBMITTED'), DamageClaimStatus.SUBMITTED);
      expect(DamageClaimStatus.fromString('UNDER_REVIEW'), DamageClaimStatus.UNDER_REVIEW);
    });
  });
}
