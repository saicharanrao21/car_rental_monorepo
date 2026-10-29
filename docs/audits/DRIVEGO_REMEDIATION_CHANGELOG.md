# DRIVEGO — REMEDIATION CHANGELOG & DEFECT RESOLUTION RECORD

**Document ID:** `AUD-DRV-2026-009`  
**Date:** October 29, 2026  
**Auditor:** Principal Enterprise Software Architect  
**Scope:** Chronological record of defects, architectural gaps, and regressions forensically discovered and remediated across the monorepo during the production readiness audit.

---

## 1. Summary of Remediated Defects

| Defect ID | Severity | Component | Summary | Status |
|---|:---:|---|---|:---:|
| **DEF-NOTIF-01** | **CRITICAL** | Backend (`NotificationOrchestratorService`) | Disconnect between Admin Notification Rules in `SystemConfig` and runtime event dispatch | **RESOLVED** |
| **DEF-COMM-01** | **HIGH** | Backend (`CommunicationRoutingService`) | Unconditional fallback to `'mock_sms'` in production environment | **RESOLVED** |
| **DEF-CTRL-01** | **HIGH** | Backend (`admin-integrations.controller.ts`) | Missing `Patch` decorator import from `@nestjs/common` causing controller failure | **RESOLVED** |
| **DEF-SRCH-01** | **MEDIUM** | Backend (`marketplace-search.service.ts`) | Candidate vehicle query did not filter out inactive service areas | **RESOLVED** |
| **DEF-BOOK-01** | **HIGH** | Backend (`bookings.service.ts`) | Missing direct server check for active service-area and city status in `createBooking` | **RESOLVED** |
| **DEF-VEND-01** | **HIGH** | Vendor App (`handover_inspection_page.dart`) | Offline inspection draft caching was blocked by live OTP form validation | **RESOLVED** |
| **DEF-VEND-02** | **MEDIUM** | Vendor App (`vendor_approval_sync_test.dart`) | `FakeVendorComplianceRepository` missing `createDepositOrder` & `verifyDepositPayment` | **RESOLVED** |
| **DEF-CUST-01** | **LOW** | Customer App (`social_auth_buttons_test.dart`) | Stale widget text expectations (`Verify Phone`, `Send OTP`) vs modern DDS design | **RESOLVED** |
| **DEF-CUST-02** | **LOW** | Customer App (`startup_flow_test.dart`) | Split brand wordmark (`Drive` + `Go`) and button text (`Continue` vs `Next`) in tests | **RESOLVED** |

---

## 2. Detailed Root Cause Analysis & Code Remediation

### 2.1. DEF-NOTIF-01: Disconnect between Dynamic Notification Rules and Runtime Event Dispatch
- **Component**: `car_rental_backend/src/notifications/notification-orchestrator.service.ts`
- **Root Cause**: `NotificationOrchestratorService.publishEvent()` determined `channelsToDispatch` solely using the recipient's personal preferences (`user.preferences`), completely ignoring the platform-wide `communications.notification_rules` table stored in `SystemConfig`. As a result, turning off a rule or disabling SMS/WhatsApp in the Super Admin Control Center had zero effect on runtime notifications.
- **Remediation**:
  1. Added private helper `getActiveRuleForEvent(eventType: string)`.
  2. If the rule is marked `isEnabled === false`, the orchestrator immediately logs policy suppression and aborts dispatch.
  3. Channel candidates are filtered against `rule.channels` before applying user preferences.
  4. TRAI Indian quiet hours (21:00 to 08:00 IST) are evaluated against `rule.quietHoursBypass`.
- **Verification Evidence**: `phase31-multi-channel-notifications.spec.ts` updated with 2 new test cases asserting rule disablement and channel filtering. **13/13 tests passed**.

---

### 2.2. DEF-COMM-01: Mock Communication Fallback in Production Environment
- **Component**: `car_rental_backend/src/integrations/communications/communication-routing.service.ts`
- **Root Cause**: Line 251 defaulted to `'mock_sms'` whenever candidate providers were exhausted, without checking `process.env.NODE_ENV`.
- **Remediation**: Added production guard:
  ```ts
  const primaryCandidate = eligibleCandidates[0];
  if (!primaryCandidate && process.env.NODE_ENV === 'production') {
    throw new Error(
      `[COMMUNICATION_ROUTING_ERROR] No eligible communication provider configured or available for channel ${targetChannel} (country: ${country}). Mock fallback is forbidden in production environment.`,
    );
  }
  const primaryProviderId = primaryCandidate ? primaryCandidate.providerId : 'mock_sms';
  ```
- **Verification Evidence**: `phase-m-enterprise-communications.spec.ts` (**44/44 passed**).

---

### 2.3. DEF-CTRL-01: Missing `Patch` Decorator Import
- **Component**: `car_rental_backend/src/integrations/admin/admin-integrations.controller.ts`
- **Root Cause**: `@Patch('notification-rules/:id/toggle')` was declared on line 576, but `Patch` was omitted from the `@nestjs/common` import statement at the top of the file, causing a `ReferenceError: Patch is not defined`.
- **Remediation**: Added `Patch` to the imports list from `@nestjs/common`.
- **Verification Evidence**: Controller boots cleanly; test suite runs with 0 compilation errors.

---

### 2.4. DEF-SRCH-01 & DEF-BOOK-01: Service Area Server-Authoritative Enforcement
- **Component**: `marketplace-search.service.ts` & `bookings.service.ts`
- **Root Cause**: While vehicles carried `serviceAreaId`, customer search and checkout did not verify that `car.serviceArea.status === 'ACTIVE'` or `car.serviceArea.city.status === 'ACTIVE'`.
- **Remediation**:
  - In `MarketplaceSearchService`: Added `OR: [{ serviceAreaId: null }, { serviceArea: { status: 'ACTIVE' } }]` to `carWhere`.
  - In `BookingsService.createBooking()`: Included `serviceArea: { include: { city: true } }` in car lookup and added explicit validation:
    ```ts
    if (car.serviceArea && car.serviceArea.status !== 'ACTIVE') {
      throw new ConflictException(
        `Cannot book vehicle: Assigned service area '${car.serviceArea.name}' is currently ${car.serviceArea.status}.`,
      );
    }
    if (car.serviceArea?.city && car.serviceArea.city.status !== 'ACTIVE') {
      throw new ConflictException(
        `Cannot book vehicle: City '${car.serviceArea.city.name}' is currently ${car.serviceArea.city.status}.`,
      );
    }
    ```
- **Verification Evidence**: `phase-m-marketplace.spec.ts` (**17/17 passed**); `src/bookings/` suite (**150/150 passed**).

---

### 2.5. DEF-VEND-01: Vendor App Offline Handover Draft Caching
- **Component**: `apps/vendor_app/lib/features/bookings/presentation/pages/handover_inspection_page.dart`
- **Root Cause**: When a vendor was in offline mode, tapping `COMPLETE HANDOVER` checked `otp.length != 6` before evaluating `if (_simulateOffline)`. If the customer was not yet able to receive or provide an OTP, the offline draft could not be saved.
- **Remediation**: Moved `if (_simulateOffline)` ahead of live OTP validation so offline inspection data (odometer, fuel, photos, damages) is safely written to `offlineInspectionDraftsProvider` and the connection lost dialog is surfaced.
- **Verification Evidence**: `phase29_10_inspection_test.dart` (**24/24 passed**).

---

### 2.6. DEF-VEND-02: Fake Vendor Compliance Repository Interface Alignment
- **Component**: `apps/vendor_app/test/vendor_approval_sync_test.dart`
- **Root Cause**: `FakeVendorComplianceRepository` lacked concrete implementations for `createDepositOrder` and `verifyDepositPayment` following the security deposit policy upgrades.
- **Remediation**: Implemented `createDepositOrder()` returning `VendorDepositOrderModel` and `verifyDepositPayment()` returning verified status map.
- **Verification Evidence**: `vendor_approval_sync_test.dart` (**3/3 passed**).

---

### 2.7. DEF-CUST-01 & DEF-CUST-02: Customer App UI Test Alignment with DDS Design
- **Component**: `apps/customer_app/test/social_auth_buttons_test.dart` & `startup_flow_test.dart`
- **Root Cause**: The customer app underwent an automotive DDS (DriveGo Design System) modernization that changed:
  - Header text from `'Verify Phone'` to `'Welcome to DriveGo'`.
  - Button text from `'Send OTP'` to `'Continue with Phone'`.
  - Splash screen wordmark from a single `'DriveGo'` text widget into a dual-styled `Row(Text('Drive'), Text('Go'))`.
  - Onboarding slide 1 title to `'Find Your Drive'` and button to `'Continue'`.
- **Remediation**: Updated test finders to match the modernized DDS UI contracts.
- **Verification Evidence**: `social_auth_buttons_test.dart` (**PASS**); `startup_flow_test.dart` (**12/12 passed**); entire customer app suite (**215/215 passed**).
