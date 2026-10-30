# DriveGo — API Contract & Inter-Service Wiring Audit

## 1. Executive Summary
This document provides a comprehensive contract audit across all REST and WebSocket endpoints in the DriveGo platform, verifying client-server payload consistency, DTO field mappings, authorization guards, and error responses between NestJS and Flutter applications.

---

## 2. API Contract Mapping & Status Table

| Module | Route & HTTP Method | Roles Guard | Request Payload / Query | Response DTO / Schema | Contract Health |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Auth** | `POST /auth/otp/send` | Public | `{ phone: string }` | `{ success: boolean, message: string }` | **ALIGNED** |
| **Auth** | `POST /auth/otp/verify` | Public | `{ phone: string, otp: string }` | `{ accessToken, refreshToken, user }` | **ALIGNED** |
| **Auth** | `POST /auth/register-vendor` | Public | `RegisterVendorDto` | `{ user, accessToken, refreshToken }` | **ALIGNED** |
| **Auth** | `POST /auth/admin/login` | Public | `{ email: string, password: string }` | `{ accessToken, refreshToken, user }` | **ALIGNED** |
| **Auth** | `GET /auth/me` | Authenticated | Headers: `Bearer <token>` | `User` with nested `Vendor`/`Customer` | **ALIGNED** |
| **Coupons** | `GET /admin/coupons` | `ADMIN`, `SUPPORT_AGENT` | Query: `PaginationDto`, `isActive` | `{ data: Coupon[], total: number }` | **ALIGNED (Fixed route in Admin UI)** |
| **Coupons** | `POST /admin/coupons` | `ADMIN` | `CreateCouponDto` | `Coupon` | **ALIGNED** |
| **Coupons** | `PATCH /admin/coupons/:id/status` | `ADMIN` | `{ isActive: boolean }` | `Coupon` | **ALIGNED** |
| **Coupons** | `GET /coupons/available` | Authenticated | Query: `city?: string` | `Coupon[]` | **ALIGNED** |
| **Coupons** | `POST /coupons/validate` | Authenticated | `{ code: string, estimatedFare: number, carId: string }` | `CouponValidationResultDto` | **ALIGNED** |
| **Vendors** | `GET /admin/vendors` | `ADMIN`, `SUPPORT_AGENT` | Query: `VendorsQueryDto` (`search`, `status`, `city`) | `{ data: Vendor[], total: number }` | **ALIGNED (Fixed search & status alias)** |
| **Vendors** | `PATCH /admin/vendors/:id/status` | `ADMIN` | `{ status: VerificationStatus }` | `Vendor` | **ALIGNED (Fixed: Route added to controller)** |
| **Vendors** | `GET /vendors/me` | `VENDOR` | Headers: `Bearer <token>` | `Vendor` (redacted owner view) | **ALIGNED** |
| **Vendors** | `POST /vendors/me/documents` | `VENDOR` | `CreateDocumentDto` | `Document` | **ALIGNED (Fixed: Auto-uploaded in registration)** |
| **Onboarding** | `GET /vendors/me/onboarding/eligibility`| `VENDOR` | Query: `bypassCache?: boolean` | `VendorEligibilityResult` | **ALIGNED** |
| **Onboarding** | `GET /vendors/me/onboarding/requirements`| `VENDOR` | Headers: `Bearer <token>` | `VendorRequirementItem[]` | **ALIGNED** |
| **Onboarding** | `POST /vendors/me/onboarding/requirements/:id/submit`| `VENDOR` | `SubmitRequirementDto` | `VendorRequirementState` | **ALIGNED (Fixed: documentUrl/metadata support)** |
| **Onboarding** | `GET /vendors/me/onboarding/deposit` | `VENDOR` | Headers: `Bearer <token>` | `VendorDepositSummary` | **ALIGNED** |
| **Onboarding** | `POST /vendors/me/onboarding/deposit/payment` | `VENDOR` | `RecordDepositPaymentDto` | `VendorSecurityDepositTransaction` | **ALIGNED** |
| **Bookings** | `POST /bookings` | `CUSTOMER` | `CreateBookingDto` (`carId`, `startDate`, `endDate`, `couponCode`) | `Booking` with server-calculated price | **ALIGNED (Server-authoritative)** |
| **Bookings** | `GET /bookings/:id` | Authenticated | Headers: `Bearer <token>` | `Booking` | **ALIGNED** |
| **Bookings** | `POST /bookings/:id/handover` | `VENDOR`, `CUSTOMER`| `SubmitHandoverDto` | `HandoverInspection` | **ALIGNED** |
| **Bookings** | `POST /bookings/:id/return` | `VENDOR`, `CUSTOMER`| `SubmitReturnDto` | `ReturnInspection` | **ALIGNED** |
| **Payments** | `POST /payments/create-order` | `CUSTOMER` | `{ bookingId: string }` | `{ orderId: string, amount: number, currency: string }` | **ALIGNED** |
| **Payments** | `POST /payments/verify` | `CUSTOMER` | `VerifyPaymentDto` (Razorpay signature) | `PaymentResultDto` | **ALIGNED** |
| **Ledger** | `GET /admin/revenue` | `ADMIN` | Query: `startDate`, `endDate` | `RevenueSummaryDto` | **ALIGNED** |
| **Ledger** | `GET /admin/payouts` | `ADMIN` | Query: `status`, `vendorId` | `VendorPayout[]` | **ALIGNED** |

---

## 3. Detailed Audit of Corrections Applied

### Contract Item 1: Admin Coupons Integration
- **Root Cause**: The route `/coupons` was missing in `app_router.dart` and `admin_shell.dart`.
- **Correction**: Route added in Flutter router, sidebar navigation element registered, and full DTO fields (`code`, `discountType`, `discountValue`, `minOrderAmount`, `maxDiscount`, `validFrom`, `validUntil`, `usageLimit`, `perUserLimit`, `description`) certified.

### Contract Item 2: Admin Vendor Search & Status Alias
- **Root Cause**: Flutter `api_admin_vendor_repository.dart` passed `status` (e.g. `status=PENDING`) and `search` query parameters, but backend `VendorsQueryDto` was expecting `verificationStatus` and lacked multi-field regex/ILIKE search.
- **Correction**: Added `search?: string` and alias `status?: VerificationStatus` to `VendorsQueryDto`. Implemented case-insensitive Prisma search in `vendors.service.ts` across business name, owner name, city, phone, and email.

### Contract Item 3: Canonical Admin Vendor Status Modification Route
- **Root Cause**: Status mutation existed under `@Patch('vendors/:id/status')` in `vendors.controller.ts`, but was omitted from `AdminVendorsController` at `/admin/vendors/:id/status`.
- **Correction**: Mounted `@Patch(':id/status')` on `AdminVendorsController` with explicit `Roles(Role.ADMIN)`.

### Contract Item 4: Document Ingestion During Registration
- **Root Cause**: Document paths picked in the registration form (`rcBookPath`, `tradeLicensePath`, `insurancePath`) were not uploaded to `/vendors/me/documents` post-registration.
- **Correction**: Added automatic document upload calls to `ApiVendorRegistrationRepository.registerVendor()` immediately after storing authentication tokens.

### Contract Item 5: Compliance Requirement Submission DTO Flexibility
- **Root Cause**: Flutter client submitted `documentUrl` and `submissionMetadata`, whereas backend `SubmitRequirementDto` expected `documentId` and `submissionData`.
- **Correction**: Updated `SubmitRequirementDto` to accept `documentUrl`, `fileUrl`, and `submissionMetadata`. Implemented automatic `Document` record creation and linking in `VendorOnboardingRequirementsService`.

### Contract Item 6: Vendor Approval Lifecycle Synchronization
- **Root Cause**: `VendorComplianceController.refreshAll()` did not trigger `checkSession()`, causing the vendor app to stay on `/registration/pending` until restart.
- **Correction**: Enhanced `refreshAll()` to await `vendorSessionProvider.checkSession()`, added `WidgetsBindingObserver` on `PendingApprovalPage`, enabling instantaneous routing to `/dashboard` upon verification.
