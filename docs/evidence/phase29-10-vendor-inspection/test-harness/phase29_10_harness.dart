import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:vendor_app/features/bookings/presentation/pages/vendor_bookings_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/vendor_booking_detail_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/handover_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/return_inspection_page.dart';

void main() {
  runApp(const ProviderScope(child: Phase2910HarnessApp()));
}

class Phase2910HarnessApp extends StatefulWidget {
  const Phase2910HarnessApp({super.key});

  @override
  State<Phase2910HarnessApp> createState() => _Phase2910HarnessAppState();
}

class _Phase2910HarnessAppState extends State<Phase2910HarnessApp> {
  int _stateIndex = 0;

  final testBookingConfirmed = BookingModel(
    id: 'bk_confirmed_01',
    customerId: 'cust_849201',
    vendorId: 'vendor_01',
    carId: 'car_hyundai_creta',
    tripType: 'Outstation',
    pickupLocation: 'Terminal 2, Mumbai Airport',
    startDate: DateTime(2026, 9, 5, 10, 0),
    endDate: DateTime(2026, 9, 8, 18, 0),
    totalFare: 9600.0,
    platformFee: 960.0,
    gstAmount: 1728.0,
    netToVendor: 8640.0,
    status: 'confirmed',
    createdAt: DateTime(2026, 9, 2),
  );

  final testBookingOngoing = BookingModel(
    id: 'bk_ongoing_02',
    customerId: 'cust_849201',
    vendorId: 'vendor_01',
    carId: 'car_hyundai_creta',
    tripType: 'Outstation',
    pickupLocation: 'Terminal 2, Mumbai Airport',
    startDate: DateTime(2026, 9, 1, 10, 0),
    endDate: DateTime(2026, 9, 4, 18, 0),
    totalFare: 9600.0,
    platformFee: 960.0,
    gstAmount: 1728.0,
    netToVendor: 8640.0,
    status: 'ongoing',
    createdAt: DateTime(2026, 8, 30),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DriveGo Vendor Inspection Harness',
      theme: AppTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: Scaffold(
        body: _buildCurrentState(),
        floatingActionButton: FloatingActionButton(
          key: const ValueKey('next_state_fab'),
          mini: true,
          backgroundColor: const Color(0xFF0066FF),
          foregroundColor: Colors.white,
          onPressed: () {
            setState(() {
              _stateIndex = (_stateIndex + 1) % 18;
            });
          },
          child: Text('${_stateIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildCurrentState() {
    switch (_stateIndex) {
      case 0:
        // 01. Operations Hub
        return const VendorBookingsPage();

      case 1:
        // 02. Booking Detail with "Start Handover Inspection"
        return const VendorBookingDetailPage(bookingId: 'bk_confirmed_01');

      case 2:
        // 03. Handover Step 0 (Identity)
        return const HandoverInspectionPage(bookingId: 'bk_confirmed_01', initialStep: 0);

      case 3:
        // 04. Handover Step 1 (Odo & Fuel)
        return const HandoverInspectionPage(bookingId: 'bk_confirmed_01', initialStep: 1);

      case 4:
        // 05. Handover Step 2 (4-Photo Burst)
        return const HandoverInspectionPage(bookingId: 'bk_confirmed_01', initialStep: 2);

      case 5:
        // 06. Handover Step 3 (Damage Clean)
        return const HandoverInspectionPage(bookingId: 'bk_confirmed_01', initialStep: 3, hasDamage: false);

      case 6:
        // 07. Handover Step 3 (Damage Added)
        return const HandoverInspectionPage(bookingId: 'bk_confirmed_01', initialStep: 3, hasDamage: true);

      case 7:
        // 08. Handover Step 4 (Review & OTP)
        return const HandoverInspectionPage(bookingId: 'bk_confirmed_01', initialStep: 4);

      case 8:
        // 09. Handover Completed Confirmation Dialog
        return const HandoverInspectionPage(bookingId: 'bk_confirmed_01', showSuccessDialog: true);

      case 9:
        // 10. Return Entry (Ongoing Booking Detail with "Start Return Inspection")
        return const VendorBookingDetailPage(bookingId: 'bk_ongoing_02');

      case 10:
        // 11. Return Step 0 (Odometer & Fuel Delta)
        return const ReturnInspectionPage(bookingId: 'bk_ongoing_02', initialStep: 0);

      case 11:
        // 12. Return Step 0 (Validation Constraint Error)
        return const ReturnInspectionPage(bookingId: 'bk_ongoing_02', initialStep: 0, showValidationError: true);

      case 12:
        // 13. Return Step 1 (4-Photos Return Burst)
        return const ReturnInspectionPage(bookingId: 'bk_ongoing_02', initialStep: 1);

      case 13:
        // 14. Return Step 2 (Before/After Damage Comparison)
        return const ReturnInspectionPage(bookingId: 'bk_ongoing_02', initialStep: 2, hasNewDamage: false);

      case 14:
        // 15. Return Step 2 (New Damage Spot Detected & Claimed)
        return const ReturnInspectionPage(bookingId: 'bk_ongoing_02', initialStep: 2, hasNewDamage: true);

      case 15:
        // 16. Return Step 3 (Review & Final Settlement)
        return const ReturnInspectionPage(bookingId: 'bk_ongoing_02', initialStep: 3);

      case 16:
        // 17. Return Completed Confirmation Dialog
        return const ReturnInspectionPage(bookingId: 'bk_ongoing_02', showSuccessDialog: true);

      case 17:
        // 18. Network Failure / Offline Mode
        return const HandoverInspectionPage(bookingId: 'bk_confirmed_01', showOfflineDialog: true);

      default:
        return const Center(child: Text('Inspection Harness Complete'));
    }
  }
}
