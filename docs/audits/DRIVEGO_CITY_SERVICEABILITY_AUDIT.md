# DRIVEGO — CITY & SERVICEABILITY CONTROL TOWER AUDIT

**Document ID:** `AUD-DRV-2026-004`  
**Date:** October 29, 2026  
**Auditor:** Principal Enterprise Software Architect & Geo-Operations Lead  
**Scope:** Forensic evaluation of city lifecycle, service area geofencing, vendor location coverage, impact preview simulations, and server-authoritative serviceability enforcement.

---

## 1. Executive Summary

DriveGo is a multi-city, multi-vendor car rental marketplace operating in India. A city in DriveGo is not a flat monolithic toggle; it comprises diverse operational territories, distinct service areas (e.g. Airport, Financial District, HiTech City, Old City), physical vendor operating yards, and transit pickup hubs.

Prior to recent remediation, marking a city active risked exposing unverified micro-markets or allowing customer bookings in areas with zero operating yards. The implementation of the **City & Serviceability Control Tower** has introduced:
1. **Hierarchical Status Modeling**: `SupportedCity` (Live/Inactive) contains `ServiceArea` (ACTIVE, COMING_SOON, INACTIVE).
2. **Impact Preview Engine**: Pre-calculates exact operational consequences (affected vehicles, active rentals, upcoming bookings) before any status change is committed.
3. **Readiness Scorecard**: Evaluates 4 core operational pillars (Vendor Coverage, Fleet Density, Yard Verification, Telematics) before permitting an area to transition from `COMING_SOON` to `ACTIVE`.
4. **Server-Authoritative Enforcement**: Hard check in `BookingsService` strictly blocks vehicle reservations in inactive areas.

---

## 2. Schema Architecture & Data Invariants

```prisma
model SupportedCity {
  id               String            @id @default(cuid())
  name             String            @unique
  normalizedName   String            @default("")
  state            String
  country          String            @default("India")
  latitude         Float
  longitude        Float
  timezone         String            @default("Asia/Kolkata")
  isActive         Boolean           @default(true)
  status           ServiceAreaStatus @default(ACTIVE)
  enabledTripTypes String[]          @default([])
  createdAt        DateTime          @default(now())
  serviceAreas     ServiceArea[]

  @@index([status])
}

model ServiceArea {
  id                String              @id @default(cuid())
  cityId            String
  city              SupportedCity       @relation(fields: [cityId], references: [id], onDelete: Cascade)
  name              String
  normalizedName    String
  status            ServiceAreaStatus   @default(ACTIVE)
  latitude          Float
  longitude         Float
  radiusMeters      Float               @default(5000)
  priority          Int                 @default(0)
  vendorAssignments VendorServiceArea[]
  cars              Car[]

  @@unique([cityId, normalizedName])
  @@index([cityId, status])
}

model VendorServiceArea {
  id            String      @id @default(cuid())
  vendorId      String
  vendor        Vendor      @relation(fields: [vendorId], references: [id], onDelete: Cascade)
  serviceAreaId String
  serviceArea   ServiceArea @relation(fields: [serviceAreaId], references: [id], onDelete: Cascade)
  isPrimary     Boolean     @default(false)
  isActive      Boolean     @default(true)

  @@unique([vendorId, serviceAreaId])
  @@index([serviceAreaId, isActive])
}
```

### Invariants Maintained:
- **Normalization Invariant**: `normalizedName` is uppercase trimmed alphanumeric string (e.g., `'HYDERABAD'`, `'HITECH_CITY'`).
- **Cascade Safety**: Deleting a city cascades to service areas but preserves immutable historical booking records.
- **Assignment Uniqueness**: A vendor can only be assigned once to a service area (`@@unique([vendorId, serviceAreaId])`).

---

## 3. Control Tower Endpoints & Capabilities

| Endpoint | Method | Role | Description |
|---|:---:|:---:|---|
| `/admin/supported-cities` | GET | `SUPER_ADMIN`, `ADMIN` | Returns all platform cities with counts of areas, active vehicles, and live vendors |
| `/admin/supported-cities` | POST | `SUPER_ADMIN` | Registers a new city with geocoordinates and default trip types |
| `/admin/supported-cities/:id/readiness` | GET | `SUPER_ADMIN`, `ADMIN` | Computes readiness percentage and blocker list for a city |
| `/admin/supported-cities/:id/impact` | GET | `SUPER_ADMIN`, `ADMIN` | Simulates customer and vendor impact if city status is toggled |
| `/admin/supported-cities/:id/toggle` | PATCH | `SUPER_ADMIN` | Toggles city active state with audit log generation |
| `/admin/service-areas` | GET | `SUPER_ADMIN`, `ADMIN` | Returns service areas filtered by `cityId` and `status` |
| `/admin/service-areas` | POST | `SUPER_ADMIN` | Creates new geofenced service area with radius and coordinates |
| `/admin/service-areas/:id/readiness` | GET | `SUPER_ADMIN`, `ADMIN` | Generates service area launch readiness report |
| `/admin/service-areas/:id/impact` | GET | `SUPER_ADMIN`, `ADMIN` | Previews active rentals and fleet impact prior to pausing area |
| `/admin/service-areas/:id/status` | PATCH | `SUPER_ADMIN` | Commits status transition (`ACTIVE` ↔ `INACTIVE` ↔ `COMING_SOON`) |

---

## 4. Impact Preview Simulation Logic

Before an operator disables a service area, the system executes:
```ts
const activeRentalsCount = await prisma.booking.count({
  where: {
    car: { serviceAreaId: areaId },
    status: { in: ['CONFIRMED', 'ONGOING'] },
    endDate: { gte: new Date() },
  },
});

const affectedVehiclesCount = await prisma.car.count({
  where: { serviceAreaId: areaId, isAvailable: true },
});
```
If `activeRentalsCount > 0`, the Super Admin UI displays a **High-Risk Caution Banner** specifying that active rentals must be honored until trip completion, while all future searches in that zone will be immediately hidden.

---

## 5. Verification & Test Evidence

1. **Backend Spec**: `car_rental_backend/src/admin/tests/readiness-impact-control-tower.spec.ts`
   - Test 1: Service area readiness calculation with blockers (PASS)
   - Test 2: Service area impact preview with active bookings count (PASS)
   - Test 3: City readiness aggregation across multi-area hierarchy (PASS)
   - Test 4: City impact preview calculation (PASS)
   - Test 5: Service area status transition updates database (PASS)
   - Test 6: City active status toggle updates database (PASS)
   - **Result**: **6/6 passed (100%)**.

2. **Admin Panel Flutter Test**: `apps/admin_panel/test/admin_city_serviceability_control_tower_test.dart`
   - Test 1: Renders City & Serviceability Control Tower with KPIs (PASS)
   - Test 2: Supported cities table renders status badges and action buttons (PASS)
   - Test 3: Service Areas Workspace sheet opens and renders areas (PASS)
   - Test 4: City readiness scorecard dialog renders progress and metrics (PASS)
   - **Result**: **4/4 passed (100%)**.
