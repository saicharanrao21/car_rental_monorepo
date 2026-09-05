# Phase 34: API Contracts — Vehicle Availability & Fleet Inventory Engine

## Overview
Phase 34 establishes a server-authoritative API surface for vehicle availability, temporary reservation holds, operational maintenance blocks, and inventory timelines. All endpoints enforce tenant isolation, role-based access control (RBAC), timestamp validation, and deterministic HTTP status codes.

---

## 1. Endpoints Summary

| Method | Path | Auth / Role | Description |
|---|---|---|---|
| `GET` | `/cars/:id/availability` | Public / Authenticated | Preflight check: Checks if a specific vehicle is available for a given time window `[startDate, endDate]`. |
| `GET` | `/cars/search/availability` | Public / Authenticated | Search available inventory in a location/city for a specific time window, excluding blocked/reserved cars. |
| `POST` | `/cars/:id/holds` | JWT (Customer, Vendor, Admin) | Create a temporary reservation hold (e.g. 15-minute checkout hold) with idempotency key. |
| `DELETE` | `/cars/holds/:holdId` | JWT (Customer, Vendor, Admin) | Manually release an active reservation hold before natural TTL expiration. |
| `POST` | `/cars/:id/blocks` | JWT (Vendor, Admin) | Place an operational block (maintenance, cleaning, vendor block, administrative hold) on a vehicle. |
| `DELETE` | `/cars/blocks/:blockId` | JWT (Vendor, Admin) | Remove an operational block, releasing vehicle back to bookable inventory. |
| `GET` | `/cars/:id/availability-timeline` | JWT (Vendor, Admin) | Retrieve operational timeline (all confirmed bookings, active holds, and blocks) for fleet management. |

---

## 2. Detailed API Specifications

### 2.1 Check Vehicle Availability
- **Method & Path**: `GET /cars/:id/availability`
- **Query Parameters**:
  - `startDate` (ISO 8601 string, required): Interval start timestamp.
  - `endDate` (ISO 8601 string, required): Interval end timestamp.
- **Request Headers**:
  - `x-tenant-id` (optional string): Current tenant context (defaults to system/car tenant).
- **Responses**:
  - `200 OK`:
    ```json
    {
      "isAvailable": true,
      "conflictingBookings": 0,
      "conflictingBlocks": 0,
      "conflictingHolds": 0,
      "reason": null
    }
    ```
  - `200 OK` (Conflict):
    ```json
    {
      "isAvailable": false,
      "conflictingBookings": 1,
      "conflictingBlocks": 0,
      "conflictingHolds": 0,
      "reason": "Vehicle has 1 active reservation(s) during this period"
    }
    ```
  - `400 Bad Request`: When `startDate >= endDate` or invalid ISO format.
  - `404 Not Found`: Vehicle ID does not exist or tenant mismatch.

---

### 2.2 Search Available Fleet Inventory
- **Method & Path**: `GET /cars/search/availability`
- **Query Parameters**:
  - `startDate` (ISO 8601 string, required)
  - `endDate` (ISO 8601 string, required)
  - `city` (string, optional)
  - `pickupLocationId` (string, optional)
- **Responses**:
  - `200 OK`: Array of available car objects (filtering out any vehicle with overlapping confirmed bookings, active maintenance blocks, or active customer holds).

---

### 2.3 Create Temporary Hold
- **Method & Path**: `POST /cars/:id/holds`
- **Auth**: JWT required (Bearer token)
- **Body**:
  ```json
  {
    "startDate": "2026-09-10T10:00:00.000Z",
    "endDate": "2026-09-15T10:00:00.000Z",
    "ttlMinutes": 15,
    "idempotencyKey": "hold-req-uuid-1234"
  }
  ```
- **Responses**:
  - `201 Created`:
    ```json
    {
      "id": "vh-uuid-abc",
      "tenantId": "tenant-1",
      "vehicleId": "car-uuid-xyz",
      "userId": "usr-uuid-cust",
      "startDate": "2026-09-10T10:00:00.000Z",
      "endDate": "2026-09-15T10:00:00.000Z",
      "expiresAt": "2026-09-05T14:25:00.000Z",
      "status": "ACTIVE",
      "idempotencyKey": "hold-req-uuid-1234"
    }
    ```
  - `409 Conflict`: Vehicle is already reserved, blocked, or held by another user.
    ```json
    {
      "statusCode": 409,
      "message": "Vehicle is unavailable: Vehicle has 1 active hold(s) during this period",
      "error": "Conflict"
    }
    ```

---

### 2.4 Release Temporary Hold
- **Method & Path**: `DELETE /cars/holds/:holdId`
- **Auth**: JWT required (Must be hold owner or Vendor/Admin)
- **Responses**:
  - `200 OK`:
    ```json
    {
      "id": "vh-uuid-abc",
      "status": "RELEASED"
    }
    ```
  - `403 Forbidden`: Hold belongs to another user and requester is not Admin/Vendor.
  - `404 Not Found`: Hold not found.

---

### 2.5 Create Vehicle Operational Block
- **Method & Path**: `POST /cars/:id/blocks`
- **Auth**: JWT required (`ADMIN`, `VENDOR`, `MANAGER`)
- **Body**:
  ```json
  {
    "type": "MAINTENANCE",
    "reason": "Scheduled 50,000 km engine service & tire rotation",
    "startDate": "2026-09-12T08:00:00.000Z",
    "endDate": "2026-09-13T18:00:00.000Z"
  }
  ```
  *(Supported types: `MAINTENANCE`, `INSPECTION`, `DAMAGE_REPAIR`, `CLEANING_DETAILING`, `VENDOR_BLOCK`, `ADMIN_BLOCK`, `SAFETY_HOLD`)*
- **Responses**:
  - `201 Created`:
    ```json
    {
      "id": "vb-uuid-block-1",
      "tenantId": "tenant-1",
      "vehicleId": "car-uuid-xyz",
      "type": "MAINTENANCE",
      "reason": "Scheduled 50,000 km engine service & tire rotation",
      "startDate": "2026-09-12T08:00:00.000Z",
      "endDate": "2026-09-13T18:00:00.000Z",
      "createdById": "vendor-uuid-789"
    }
    ```
  - `403 Forbidden`: Customers cannot create blocks; Vendors cannot block vehicles outside their tenant or fleet.
  - `409 Conflict`: Conflict with an existing confirmed booking during the requested maintenance period.

---

### 2.6 Delete Vehicle Operational Block
- **Method & Path**: `DELETE /cars/blocks/:blockId`
- **Auth**: JWT required (`ADMIN`, `VENDOR`)
- **Responses**:
  - `200 OK`:
    ```json
    {
      "id": "vb-uuid-block-1",
      "message": "Block released successfully"
    }
    ```
  - `404 Not Found`: Block does not exist.

---

### 2.7 Get Vehicle Availability Timeline
- **Method & Path**: `GET /cars/:id/availability-timeline`
- **Auth**: JWT required (`ADMIN`, `VENDOR`)
- **Query Parameters**:
  - `startDate` (ISO 8601 string, required)
  - `endDate` (ISO 8601 string, required)
- **Responses**:
  - `200 OK`:
    ```json
    {
      "vehicleId": "car-uuid-xyz",
      "startDate": "2026-09-01T00:00:00.000Z",
      "endDate": "2026-09-30T23:59:59.000Z",
      "bookings": [
        {
          "id": "b-1",
          "bookingNumber": "DRV-1001",
          "startDate": "2026-09-05T10:00:00.000Z",
          "endDate": "2026-09-08T10:00:00.000Z",
          "status": "CONFIRMED"
        }
      ],
      "blocks": [
        {
          "id": "vb-1",
          "type": "MAINTENANCE",
          "reason": "Engine service",
          "startDate": "2026-09-12T08:00:00.000Z",
          "endDate": "2026-09-13T18:00:00.000Z"
        }
      ],
      "holds": []
    }
    ```

---

## 3. Concurrency & Error Contracts
When concurrent operations collide on the same vehicle:
- The distributed Redis lock (`lock:vehicle:reservation:{vehicleId}`) serializes access.
- Inside the atomic transaction, the conflicting record raises an HTTP `409 Conflict` error with a structured JSON message indicating the exact conflict reason.
- Repeated requests with the identical `idempotencyKey` return the existing record without duplicate allocation.
