# DriveGo — Vendor App System Wiring & Verification Matrix

## 1. Overview & Verification Status
This matrix details the full-stack wiring of the DriveGo Vendor Mobile Application (`apps/vendor_app`), verifying every screen, registration step, Riverpod provider, repository call, backend endpoint, and Prisma database entity.

---

## 2. Vendor App End-to-End Wiring Matrix

| Functional Area | Screen / Route | Riverpod State Provider | Repository & API Call | Backend Controller & Endpoint | Prisma Entity | Audit & Verification Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Auth & Access** | `/auth/phone` | `vendorAuthPhoneProvider` | `ApiVendorAuthRepo` -> `POST /auth/otp/send` | `AuthController.sendOtp` (`POST /auth/otp/send`) | `OtpRequest` | **CERTIFIED** |
| **Auth & Access** | `/auth/otp` | `vendorOtpNotifier` | `ApiVendorAuthRepo` -> `POST /auth/otp/verify` | `AuthController.verifyOtp` (`POST /auth/otp/verify`) | `User`, `Vendor` | **CERTIFIED** |
| **Onboarding** | `/registration` | `vendorRegistrationDraftProvider` | `ApiVendorRegistrationRepo` -> `POST /auth/register-vendor` | `AuthController.registerVendor` (`POST /auth/register-vendor`) | `User`, `Vendor` | **CERTIFIED** |
| **Onboarding** | Document Upload | `vendorRegistrationDraftProvider` | `ApiVendorRegistrationRepo` -> `POST /vendors/me/documents` | `VendorsController.addDocument` (`POST /vendors/me/documents`) | `Document` (`RC_BOOK`, `TRADE_LICENSE`, `INSURANCE`) | **CERTIFIED (Fixed: Auto-uploaded on registration)** |
| **Onboarding** | `/registration/pending` | `vendorEligibilityProvider` | `ApiVendorComplianceRepo` -> `GET /vendors/me/onboarding/eligibility` | `VendorOnboardingController.getEligibility` | `VendorRequirementState`, `Vendor` | **CERTIFIED** |
| **Onboarding** | Requirements List | `vendorRequirementsProvider` | `ApiVendorComplianceRepo` -> `GET /vendors/me/onboarding/requirements` | `VendorOnboardingController.getRequirements` | `OnboardingRequirementDefinition`, `VendorRequirementState` | **CERTIFIED** |
| **Onboarding** | Submit Requirement | `vendorComplianceControllerProvider` | `ApiVendorComplianceRepo` -> `POST /vendors/me/onboarding/requirements/:id/submit` | `VendorOnboardingController.submitRequirement` | `VendorRequirementState`, `Document` | **CERTIFIED (Fixed: DTO handles documentUrl/submissionMetadata)** |
| **Onboarding** | Security Deposit | `vendorDepositSummaryProvider` | `ApiVendorComplianceRepo` -> `GET /vendors/me/onboarding/deposit` | `VendorOnboardingController.getDeposit` | `VendorSecurityDeposit`, `LedgerAccount` | **CERTIFIED** |
| **Onboarding** | Pay Deposit | `vendorComplianceControllerProvider` | `ApiVendorComplianceRepo` -> `POST /vendors/me/onboarding/deposit/payment` | `VendorOnboardingController.recordDepositPayment` | `VendorSecurityDepositTransaction`, `LedgerTransaction` | **CERTIFIED** |
| **Approval Sync** | Auto-Sync to Dash | `vendorSessionProvider` & `vendorApprovalStatusProvider` | `ApiVendorComplianceRepo.refreshAll()` -> `GET /auth/me` | `AuthController.me` (`GET /auth/me`) | `Vendor.verificationStatus` | **CERTIFIED (Fixed: App resume & pull-to-refresh routes to /dashboard)** |
| **Fleet Operations**| `/dashboard` | `vendorDashboardStatsProvider` | `ApiVendorFleetRepo` -> `GET /vendors/me/analytics` | `VendorsController.getVendorAnalytics` | `Vendor`, `Car`, `Booking` | **CERTIFIED** |
| **Fleet Operations**| `/fleet` | `vendorFleetListProvider` | `ApiVendorFleetRepo` -> `GET /vendors/me/cars` | `VendorsController.getMyCars` | `Car`, `MileagePackage`, `Document` | **CERTIFIED** |
| **Fleet Operations**| Add Vehicle | `vendorCarAddNotifier` | `ApiVendorFleetRepo` -> `POST /cars` | `CarsController.create` (`POST /cars`) | `Car` | **CERTIFIED** |
| **Fleet Operations**| Vehicle Documents | `vendorCarDocumentsProvider` | `ApiVendorFleetRepo` -> `POST /vendors/me/documents` | `VendorsController.addDocument` | `Document` | **CERTIFIED** |
| **Fulfillment** | `/bookings` | `vendorBookingsProvider` | `ApiVendorBookingsRepo` -> `GET /vendors/me/bookings` | `BookingsController.getVendorBookings` | `Booking`, `Car`, `User` | **CERTIFIED** |
| **Fulfillment** | Handover Inspect | `vendorHandoverNotifier` | `ApiVendorBookingsRepo` -> `POST /bookings/:id/handover` | `BookingsController.submitHandover` | `HandoverInspection`, `Booking` | **CERTIFIED** |
| **Fulfillment** | Complete & Return | `vendorReturnNotifier` | `ApiVendorBookingsRepo` -> `POST /bookings/:id/return` | `BookingsController.submitReturn` | `ReturnInspection`, `DamageClaim` | **CERTIFIED** |
| **Payouts & Escrow**| `/payouts` | `vendorPayoutsProvider` | `ApiVendorEarningsRepo` -> `GET /vendors/me/payouts` | `VendorsController.getPayouts` | `VendorPayout`, `LedgerTransaction` | **CERTIFIED** |
| **Multi-Branch** | `/branches` | `vendorBranchesProvider` | `ApiVendorBranchesRepo` -> `GET /vendors/me/branches` | `VendorsController.getMyBranches` | `VendorBranch`, `PickupHub` | **CERTIFIED** |

---

## 3. Audited Gaps & Closed Items

### 3.1 Document Upload on Registration
- **Prior Problem**: The registration draft stepper gathered `rcBookPath`, `tradeLicensePath`, and `insurancePath`, but `registerVendor()` only created the `User` and `Vendor` rows without persisting or attaching the documents.
- **Resolution**: Updated `api_vendor_registration_repository.dart` to immediately upload picked files via `POST /vendors/me/documents` upon acquiring authentication tokens.

### 3.2 Requirement Submission Payload Compatibility
- **Prior Problem**: Flutter compliance repository sent `documentUrl` and `submissionMetadata`, whereas backend `SubmitRequirementDto` expected `documentId` and `submissionData`.
- **Resolution**:
  - Updated `SubmitRequirementDto` to accept `documentUrl`, `fileUrl`, and `submissionMetadata`.
  - Updated `VendorOnboardingRequirementsService.submitRequirement()` to auto-create and link a `Document` entity when a URL is supplied without a pre-existing `documentId`.

### 3.3 Vendor Approval State Synchronization & Automatic Navigation
- **Prior Problem**: When an admin approved a vendor, the vendor app remained on `/registration/pending` until a manual app restart because `refreshAll()` only invalidated requirement caches without refreshing the root `vendorSessionProvider`.
- **Resolution**:
  - Enhanced `VendorComplianceController.refreshAll()` to invoke `ref.read(vendorSessionProvider.notifier).checkSession()`.
  - Added `WidgetsBindingObserver` to `PendingApprovalPage` to trigger `refreshAll()` whenever the app resumes from the background.
  - Verified that GoRouter dynamically transitions the user to `/dashboard` upon receiving the verified status (verified via `test/vendor_approval_sync_test.dart`).
