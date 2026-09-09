# Phase O Implementation Plan — Enterprise Reservation, Fulfillment & Financial Integrity Hardening

## 1. Objectives & Scope

Phase O hardens the DriveGo / PlayHub enterprise platform by resolving the critical gaps identified in the Phase N Pre-Audit:
- **Security & Authorization**: Enforce JWT auth guards, RBAC, tenant scoping, and strict DTO validation across all fulfillment and operations controllers.
- **Transactional State Integrity**: Bridge `BookingLifecycleService` and `FulfillmentOrchestratorService` so commercial status and physical fulfillment stay in lockstep across confirmation, cancellation, pickup, and return.
- **End-to-End Pricing Integrity**: Connect `DemandAwarePricingService` directly into `PricingService.generateQuote` with deterministic policy caps.
- **Autonomous Operational Sweeps**: Add automated background jobs for sweeping expired vehicle holds (`VehicleHold`), evaluating SLA breaches periodically, and handling rebalancing proposals.
- **Multilateral Financial Settlement**: Wire `MarketplaceCommissionService` into booking confirmation and payment reconciliation.
- **Corporate Account Services**: Implement `CorporateAccountsService` and REST endpoints for B2B billing and negotiated rates.
- **Frontend Operational Integration**: Wire Phase N/O APIs to Admin Panel and Vendor App dashboards.

---

## 2. Component Changes

### A. Security & Controller Hardening
- **Files**:
  - `car_rental_backend/src/fulfillment/dto/fulfillment-requests.dto.ts` [NEW]
  - `car_rental_backend/src/fulfillment/fulfillment.controller.ts` [MODIFY]
  - `car_rental_backend/src/operations/dto/command-center.dto.ts` [NEW]
  - `car_rental_backend/src/operations/command-center.controller.ts` [MODIFY]
- **Changes**:
  - Decorate `FulfillmentController` and `CommandCenterController` with `@UseGuards(JwtAuthGuard, RolesGuard)`.
  - Add `@Roles(Role.VENDOR, Role.ADMIN)` to fulfillment operations and vendor command center.
  - Add `@Roles(Role.ADMIN)` to admin command center, SLA evaluation, and rebalancing recommendations.
  - Enforce tenant isolation by extracting `vendorId` directly from `req.user.vendorId` (prevent query parameter injection).
  - Add `class-validator` DTOs for all request bodies (`StartPreparationDto`, `MarkCleanedDto`, `MarkInspectedDto`, `MarkReadyForPickupDto`, `CustomerArrivalDto`, `EvaluateSubstitutionDto`, `ExecuteSubstitutionDto`, `ResolveIncidentDto`).

### B. Booking $\leftrightarrow$ Fulfillment Transactional Lifecycle Bridge
- **Files**:
  - `car_rental_backend/src/bookings/booking-lifecycle.service.ts` [MODIFY]
  - `car_rental_backend/src/bookings/bookings.module.ts` [MODIFY]
  - `car_rental_backend/src/fulfillment/fulfillment-orchestrator.service.ts` [MODIFY]
- **Changes**:
  - Inject `FulfillmentOrchestratorService` (via `forwardRef`) into `BookingLifecycleService`.
  - In `confirmBooking`: Transactionally call `initializeFulfillment(booking.id)` ensuring physical tracking begins at `ALLOCATED` stage.
  - In `cancelBooking` / `rejectBooking`: Transactionally update `FulfillmentRecord` to `CANCELLED`, clear vehicle preparation tasks, and log audit outbox event.
  - In `markReadyForHandover`: Update `FulfillmentRecord` to `READY_FOR_PICKUP`.
  - In `startRental`: Verify vehicle is staged/inspected, update `FulfillmentRecord` to `ACTIVE_RENTAL`.
  - In `completeRental`: Update `FulfillmentRecord` to `RETURN_INSPECTION` $\to$ `SETTLEMENT_PENDING` $\to$ `FULFILLMENT_CLOSED`.

### C. Dynamic Pricing Integration into Canonical Quotes
- **Files**:
  - `car_rental_backend/src/pricing/pricing.service.ts` [MODIFY]
  - `car_rental_backend/src/pricing/pricing.module.ts` [MODIFY]
- **Changes**:
  - Inject `DemandAwarePricingService` into `PricingService`.
  - In `PricingService.generateQuote`:
    - Call `demandAwarePricingService.calculateDynamicPrice` using the vehicle, vendor, and reservation date window.
    - If demand surge applies, reflect base price and demand factor within bounded limits (`minDailyPrice`, `maxDailyPrice`, `maxSurgeMultiplier`).
    - Record pricing basis and multiplier in quote line item description / metadata.

### D. Automated Background Sweeps & Resilience
- **Files**:
  - `car_rental_backend/src/bookings/rental-automation.service.ts` [MODIFY]
  - `car_rental_backend/src/operations/sla-escalation.service.ts` [MODIFY]
- **Changes**:
  - Add `expireStaleVehicleHolds()` to `RentalAutomationService` to sweep expired temporary holds (`status: ACTIVE` and `expiresAt < now`) to `EXPIRED`.
  - Add `evaluateOperationalSlas()` to `RentalAutomationService` invoking `SlaEscalationEngineService.evaluateAllSlas()`.
  - Add recurring cron/ticker triggers using `@Cron(CronExpression.EVERY_5_MINUTES)` in `RentalAutomationService`.
  - Add `resolveIncident` endpoint in `CommandCenterController` (`POST /api/v1/operations/admin/sla/incidents/:id/resolve`).

### E. Multilateral Marketplace Commission Integration
- **Files**:
  - `car_rental_backend/src/bookings/booking-lifecycle.service.ts` [MODIFY]
  - `car_rental_backend/src/payments/enterprise-reconciliation.service.ts` [MODIFY]
- **Changes**:
  - In `BookingLifecycleService.confirmBooking`, invoke `MarketplaceCommissionService.calculateCommissionSplit` and persist the immutable multilateral financial breakdown into booking `priceSnapshot` or metadata.
  - Ensure reconciliation records check platform, vendor, and gateway shares.

### F. Corporate Accounts Core Service & API
- **Files**:
  - `car_rental_backend/src/corporate/corporate-accounts.service.ts` [NEW]
  - `car_rental_backend/src/corporate/corporate-accounts.controller.ts` [NEW]
  - `car_rental_backend/src/corporate/dto/corporate-account.dto.ts` [NEW]
  - `car_rental_backend/src/corporate/corporate.module.ts` [NEW]
  - `car_rental_backend/src/app.module.ts` [MODIFY]
- **Changes**:
  - Create full CRUD and credit validation service for B2B corporate rentals using existing `CorporateAccount` Prisma model.
  - Expose endpoints under `/api/v1/corporate-accounts` with `@Roles(Role.ADMIN)`.

### G. Frontend Integration
- **Files**:
  - `apps/admin_panel/lib/features/dashboard/data/api_admin_dashboard_repository.dart` [MODIFY]
  - `apps/admin_panel/lib/features/dashboard/domain/repositories/admin_dashboard_repository.dart` [MODIFY]
  - `apps/vendor_app/lib/features/dashboard/data/api_dashboard_repository.dart` [MODIFY]
- **Changes**:
  - Add client integration methods for fetching real-time operational command center metrics and SLA breach alerts.
  - Maintain 100% backward compatibility and resilience.

---

## 3. Verification & Testing Plan

### Automated Backend Tests
- Create `car_rental_backend/test/phase-o-enterprise-reservation-financial-integrity.spec.ts` testing:
  - Fulfillment controller JWT and role guards (unauthorized rejection, vendor isolation).
  - Booking confirmation $\to$ Fulfillment initialization.
  - Booking cancellation $\to$ Fulfillment cancellation & bay release.
  - PricingService generating quote with dynamic demand multiplier.
  - Stale vehicle hold expiration sweep.
  - SLA breach detection & incident resolution.
  - Multilateral commission calculation & snapshot persistence.
  - Corporate account credit verification.
- Run `npm test` across all 115+ test suites (ensuring 0 regressions).
- Run `npm run build` (ensuring 0 TypeScript errors).

### Frontend Verification
- Run `flutter analyze apps/customer_app apps/vendor_app apps/admin_panel` (ensuring 0 issues).
- Run `flutter test apps/customer_app`.
- Run `flutter test apps/admin_panel`.
- Run `flutter test apps/vendor_app`.
