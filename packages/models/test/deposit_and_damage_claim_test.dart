import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('SecurityDepositModel', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime.now();
      final deposit = SecurityDepositModel(
        id: 'dep_1',
        bookingId: 'book_1',
        amount: 5000.0,
        refundedAmount: 5000.0,
        deductedAmount: 0.0,
        razorpayPaymentId: 'pay_123',
        razorpayRefundId: 'rfnd_456',
        status: SecurityDepositStatus.REFUNDED,
        heldAt: now,
        releasedAt: now,
        createdAt: now,
      );

      final json = deposit.toJson();
      final fromJson = SecurityDepositModel.fromJson(json);

      expect(fromJson.id, 'dep_1');
      expect(fromJson.bookingId, 'book_1');
      expect(fromJson.amount, 5000.0);
      expect(fromJson.status, SecurityDepositStatus.REFUNDED);
      expect(fromJson.razorpayRefundId, 'rfnd_456');
    });

    test('handles default status parsing', () {
      final deposit = SecurityDepositModel.fromJson({
        'id': 'dep_2',
        'bookingId': 'book_2',
        'amount': 3000,
      });

      expect(deposit.status, SecurityDepositStatus.REQUIRED);
      expect(deposit.refundedAmount, 0.0);
      expect(deposit.collateralType, CollateralType.monetaryOnline);
    });

    test('serializes and deserializes physical vehicle collateral correctly', () {
      final now = DateTime.now();
      final deposit = SecurityDepositModel(
        id: 'dep_vehicle_1',
        bookingId: 'book_veh_1',
        amount: 0.0,
        status: SecurityDepositStatus.HELD,
        collateralType: CollateralType.physicalVehicle,
        vehicleRegistrationNumber: 'KA-05-MM-1234',
        vehicleMakeModel: 'Yamaha FZ-S',
        vehicleKeyCollected: true,
        physicalStorageLocation: 'Yard Bay 4B',
        notes: 'Keys kept in locker #12',
        heldAt: now,
        createdAt: now,
      );

      final json = deposit.toJson();
      final parsed = SecurityDepositModel.fromJson(json);

      expect(parsed.id, 'dep_vehicle_1');
      expect(parsed.collateralType, CollateralType.physicalVehicle);
      expect(parsed.vehicleRegistrationNumber, 'KA-05-MM-1234');
      expect(parsed.vehicleMakeModel, 'Yamaha FZ-S');
      expect(parsed.vehicleKeyCollected, true);
      expect(parsed.physicalStorageLocation, 'Yard Bay 4B');
      expect(parsed.notes, 'Keys kept in locker #12');
    });

    test('serializes and deserializes original document safe vault collateral', () {
      final now = DateTime.now();
      final deposit = SecurityDepositModel(
        id: 'dep_doc_1',
        bookingId: 'book_doc_1',
        amount: 0.0,
        status: SecurityDepositStatus.HELD,
        collateralType: CollateralType.originalDocument,
        documentType: 'PASSPORT',
        documentIdentifier: 'Z1234567',
        physicalStorageLocation: 'Safe Vault Box #07',
        heldAt: now,
        createdAt: now,
      );

      final json = deposit.toJson();
      final parsed = SecurityDepositModel.fromJson(json);

      expect(parsed.collateralType, CollateralType.originalDocument);
      expect(parsed.documentType, 'PASSPORT');
      expect(parsed.documentIdentifier, 'Z1234567');
      expect(parsed.physicalStorageLocation, 'Safe Vault Box #07');
    });
  });

  group('CollateralRecordModel (P0 Collateral Separation)', () {
    test('serializes and deserializes physical vehicle CollateralRecordModel correctly', () {
      final now = DateTime.now();
      final collateral = CollateralRecordModel(
        id: 'col_rec_1',
        bookingId: 'book_veh_100',
        collateralType: CollateralType.physicalVehicle,
        status: CollateralRecordStatus.HELD,
        vehicleRegistrationNumber: 'KA-01-MJ-1234',
        vehicleMake: 'Honda',
        vehicleModel: 'Activa 6G',
        yardSlotNumber: 'BAY-09',
        keysCollected: true,
        notes: 'Keys kept in vault #12',
        photoUrls: ['https://example.com/vehicle1.jpg'],
        heldAt: now,
        createdAt: now,
      );

      final json = collateral.toJson();
      final parsed = CollateralRecordModel.fromJson(json);

      expect(parsed.id, 'col_rec_1');
      expect(parsed.bookingId, 'book_veh_100');
      expect(parsed.collateralType, CollateralType.physicalVehicle);
      expect(parsed.status, CollateralRecordStatus.HELD);
      expect(parsed.vehicleRegistrationNumber, 'KA-01-MJ-1234');
      expect(parsed.vehicleMake, 'Honda');
      expect(parsed.vehicleModel, 'Activa 6G');
      expect(parsed.yardSlotNumber, 'BAY-09');
      expect(parsed.keysCollected, true);
      expect(parsed.photoUrls.length, 1);
    });

    test('serializes and deserializes original document CollateralRecordModel correctly', () {
      final now = DateTime.now();
      final collateral = CollateralRecordModel(
        id: 'col_rec_2',
        bookingId: 'book_doc_200',
        collateralType: CollateralType.originalDocument,
        status: CollateralRecordStatus.RETURNED,
        documentType: 'PASSPORT',
        documentNumberMasked: 'Z8765432',
        vaultLockerNumber: 'SAFE-08',
        verifiedPhysically: true,
        notes: 'Document returned in person',
        heldAt: now,
        releasedAt: now,
        createdAt: now,
      );

      final json = collateral.toJson();
      final parsed = CollateralRecordModel.fromJson(json);

      expect(parsed.id, 'col_rec_2');
      expect(parsed.collateralType, CollateralType.originalDocument);
      expect(parsed.status, CollateralRecordStatus.RETURNED);
      expect(parsed.documentType, 'PASSPORT');
      expect(parsed.documentNumberMasked, 'Z8765432');
      expect(parsed.vaultLockerNumber, 'SAFE-08');
      expect(parsed.verifiedPhysically, true);
      expect(parsed.releasedAt, isNotNull);
    });
  });

  group('DamageClaimModel', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime.now();
      final claim = DamageClaimModel(
        id: 'claim_1',
        bookingId: 'book_1',
        vendorId: 'vend_1',
        claimedAmount: 2500.0,
        approvedAmount: 2000.0,
        status: DamageClaimStatus.PARTIALLY_APPROVED,
        description: 'Rear bumper scratch',
        damagePhotos: ['photo1.jpg', 'photo2.jpg'],
        vendorNotes: 'Deep scratch',
        adminNotes: 'Approved based on post-trip photos',
        createdAt: now,
      );

      final json = claim.toJson();
      final fromJson = DamageClaimModel.fromJson(json);

      expect(fromJson.id, 'claim_1');
      expect(fromJson.claimedAmount, 2500.0);
      expect(fromJson.approvedAmount, 2000.0);
      expect(fromJson.status, DamageClaimStatus.PARTIALLY_APPROVED);
      expect(fromJson.damagePhotos.length, 2);
    });
  });
}
