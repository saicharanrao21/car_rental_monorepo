# DriveGo Self-Drive Mobility Marketplace — Acceptance Test & Regression Plan

**Document Reference:** `TEST-REG-08`  
**Version:** 2.0.0-PROD  
**Author:** DriveGo QA Lead & Senior Automation Engineer  
**Scope:** Automated Test Suites, E2E Acceptance Scenarios, and Regression Harness  
**Status:** Approved for Implementation

---

## 1. Master Acceptance Test Matrix

| Test Suite ID | Test Case Title | Target Component | Execution Method | Pass Criteria |
|:---|:---|:---|:---|:---|
| **TC-DEP-01** | Authoritative Policy Update & Fetch | Admin Panel -> Backend -> Vendor App | Integration Test / Widget Test | Admin sets ₹15,000; newly onboarding vendor fetches exactly ₹15,000 from backend. |
| **TC-DEP-02** | No Arbitrary Silent Fallback | Backend `VendorSecurityDepositService` | Unit Test | When no active policy exists, backend throws `NotFoundException` rather than applying silent ₹25,000 fallback. |
| **TC-DEP-03** | HMAC Signature Verification & Ledger Integrity | Razorpay Webhook & Payment Service | Unit Test | Invalid HMAC signature is rejected with HTTP 400; valid signature marks deposit `PAID` and writes ledger journal entry. |
| **TC-DEP-04** | Exemption Waiver Governance | Admin Panel -> Backend | Unit Test / API Test | Super Admin waives deposit with reason; vendor eligibility activates immediately without Razorpay payment. |
| **TC-PHT-01** | Zero Stock Photo Assertion | Vendor App `AddEditCarPage` | Widget Test | `samplePhotos` is completely absent; form does NOT initialize with stock images; submit requires authentic uploaded photos. |
| **TC-PHT-02** | Presigned S3 Upload Pipeline | `UploadService` -> `POST /uploads/presign` | Unit / Mock Test | Requests presigned URL for `car-photo`; uploads bytes; returns public asset URL. |
| **TC-PHT-03** | Photo Thumbnail Preview & Removal | Vendor App `AddEditCarPage` | Widget Test | Uploaded image displays preview; tapping remove removes URL from state and updates count. |
| **TC-PUB-01** | Bounded Timeout & Spinner Dismissal | Vendor App Fleet Controller | Widget Test | Server latency > 15s triggers timeout; UI dismisses loader and displays actionable error message without getting stuck. |
| **TC-PUB-02** | Explicit Publication Lifecycle Transition | Backend `VendorFleetService` | Integration Test | Vehicle creates in `DRAFT` / `PENDING_VERIFICATION`; admin approves -> `VERIFIED`; vendor activates -> `ACTIVE`. |
| **TC-LOC-01** | Vendor Genuine Operating Yard Creation | Backend `LocationsController` | Unit / Integration Test | Vendor registers "Gachibowli Operations Yard"; saved with correct vendorId and coordinates. |
| **TC-LOC-02** | Cross-Vendor Yard Isolation | Backend `LocationsService` | Unit Test | Vendor B attempting to update or assign Vendor A's pickup yard is rejected with HTTP 403 Forbidden. |
| **TC-LOC-03** | Vehicle-to-Yard Association | Backend `VendorFleetService` | Integration Test | Vehicle created with valid `pickupHubId` binds successfully; invalid `pickupHubId` throws HTTP 400. |
| **TC-SOD-01** | High-Value Payout Dual-Authorization | Backend `PayoutsService` | Unit Test | Payout > ₹50,000 rejected if executor is same user as approver (`approverId == executorId`). |
| **TC-DPDP-01**| Customer Right to Erasure / Anonymization | Backend `UsersService` | Unit Test | Anonymizes user PII if no active bookings; preserves double-entry financial ledger records for 7-year audit. |

---

## 2. Regression Test Execution Commands

```bash
# 1. Backend Staff, RBAC & Deposit Tests
cd car_rental_backend
npm test -- src/admin/admin-staff.spec.ts
npm test -- src/vendors/onboarding/vendor-deposit-razorpay.spec.ts
npm test -- src/payouts/payouts.service.spec.ts

# 2. Flutter Vendor App Tests
cd ../apps/vendor_app
flutter test test/vendor_vehicle_photo_and_publishing_test.dart
flutter test test/vendor_security_deposit_flow_test.dart

# 3. Flutter Admin Panel Tests
cd ../apps/admin_panel
flutter test test/admin_staff_management_test.dart
flutter test test/admin_deposit_policy_management_test.dart
```
