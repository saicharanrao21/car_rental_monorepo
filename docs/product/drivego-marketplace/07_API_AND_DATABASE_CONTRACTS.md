# DriveGo Self-Drive Mobility Marketplace — API & Database Contracts

**Document Reference:** `CONTRACT-API-07`  
**Version:** 2.0.0-PROD  
**Author:** DriveGo Principal Software Architect & Database Engineer  
**Scope:** HTTP Endpoints, Validation DTOs, JSON Schemas, and Prisma Models  
**Status:** Approved for Implementation

---

## 1. Authoritative API Contracts

### 1.1 Vendor Security Deposit Endpoints

#### `GET /vendors/me/onboarding/deposit`
- **Guards:** `JwtAuthGuard`, `Roles(Role.VENDOR)`
- **Response `200 OK`:**
  ```json
  {
    "depositId": "dep_cm123abc",
    "vendorId": "vnd_987xyz",
    "policyVersion": 2,
    "isRequired": true,
    "requiredAmount": 15000.0,
    "paidAmount": 0.0,
    "remainingAmount": 15000.0,
    "currency": "INR",
    "refundPolicy": "REFUNDABLE",
    "deadlineDays": 14,
    "status": "PENDING",
    "isExempted": false,
    "exemptionReason": null,
    "policyDescription": "DriveGo Partner Standard Security Deposit. 100% refundable upon partner contract termination.",
    "refundConditions": "Refundable within 30 days of contract termination subject to zero outstanding liabilities."
  }
  ```

#### `POST /vendors/me/onboarding/deposit/create-order`
- **Guards:** `JwtAuthGuard`, `Roles(Role.VENDOR)`
- **Response `201 CREATED`:**
  ```json
  {
    "orderId": "order_RZP12345678",
    "amount": 1500000,
    "currency": "INR",
    "keyId": "rzp_test_12345",
    "vendorId": "vnd_987xyz",
    "depositId": "dep_cm123abc",
    "purpose": "VENDOR_SECURITY_DEPOSIT"
  }
  ```

#### `POST /vendors/me/onboarding/deposit/verify-payment`
- **Guards:** `JwtAuthGuard`, `Roles(Role.VENDOR)`
- **Request Body (`VerifyDepositPaymentDto`):**
  ```json
  {
    "orderId": "order_RZP12345678",
    "paymentId": "pay_RZP87654321",
    "signature": "c8f94d21e86b245781..."
  }
  ```
- **Response `200 OK`:**
  ```json
  {
    "success": true,
    "depositId": "dep_cm123abc",
    "status": "PAID",
    "paidAmount": 15000.0,
    "remainingAmount": 0.0,
    "transactionId": "txn_ledger_99"
  }
  ```

---

### 1.2 Presigned Vehicle Photo Upload Endpoints

#### `POST /uploads/presign`
- **Guards:** `JwtAuthGuard`
- **Request Body (`PresignUploadDto`):**
  ```json
  {
    "fileType": "car-photo",
    "contentType": "image/jpeg"
  }
  ```
- **Response `201 CREATED`:**
  ```json
  {
    "key": "car-photo/usr_123/1730193400-ab12cd34.jpg",
    "uploadUrl": "https://storage.drivego.in/upload?signed=...",
    "publicUrl": "https://assets.drivego.in/car-photo/usr_123/1730193400-ab12cd34.jpg"
  }
  ```

---

### 1.3 Fleet Creation & Lifecycle Endpoints

#### `POST /vendor/fleet`
- **Guards:** `JwtAuthGuard`, `Roles(Role.VENDOR)`
- **Request Body (`CreateCarDto`):**
  ```json
  {
    "make": "Hyundai",
    "model": "Creta",
    "year": 2024,
    "type": "SUV",
    "fuelType": "PETROL",
    "seating": 5,
    "isAC": true,
    "registrationNumber": "TS09FA1234",
    "photos": [
      "https://assets.drivego.in/car-photo/usr_123/front.jpg",
      "https://assets.drivego.in/car-photo/usr_123/side.jpg"
    ],
    "pricePerKm": 14.0,
    "pricePerDay": 2400.0,
    "pricePerHour": 180.0,
    "availableTripTypes": ["SELF_DRIVE", "OUTSTATION"],
    "pickupHubId": "hub_hyd_gachibowli_01"
  }
  ```
- **Response `201 CREATED`:**
  ```json
  {
    "id": "car_abc123",
    "vendorId": "vnd_987xyz",
    "make": "Hyundai",
    "model": "Creta",
    "registrationNumber": "TS09FA1234",
    "photos": ["https://assets.drivego.in/car-photo/usr_123/front.jpg", "https://assets.drivego.in/car-photo/usr_123/side.jpg"],
    "pickupHubId": "hub_hyd_gachibowli_01",
    "operationalStatus": "DRAFT",
    "verificationStatus": "PENDING",
    "isAvailable": false
  }
  ```

---

### 1.4 Vendor Operating Locations / Hubs Endpoints

#### `GET /locations/vendors/me/hubs`
- **Guards:** `JwtAuthGuard`, `Roles(Role.VENDOR)`
- **Response `200 OK`:**
  ```json
  [
    {
      "id": "hub_hyd_gachibowli_01",
      "vendorId": "vnd_987xyz",
      "name": "Apex Fleet Yard 1",
      "address": "Plot 18, Telecom Nagar, Gachibowli",
      "locality": "Gachibowli",
      "city": "Hyderabad",
      "state": "Telangana",
      "latitude": 17.4401,
      "longitude": 78.3489,
      "operatingHours": "06:00 - 23:00",
      "contactPhone": "+919876543210",
      "isActive": true,
      "vehicleCount": 4
    }
  ]
  ```

#### `POST /locations/hubs`
- **Guards:** `JwtAuthGuard`, `Roles(Role.VENDOR, Role.ADMIN)`
- **Request Body (`CreatePickupHubDto`):**
  ```json
  {
    "name": "Apex Fleet Yard 2",
    "address": "Opposite Botanical Garden, Kondapur",
    "locality": "Kondapur",
    "city": "Hyderabad",
    "state": "Telangana",
    "latitude": 17.4612,
    "longitude": 78.3654,
    "operatingHours": "07:00 - 22:00",
    "contactPhone": "+919876543210"
  }
  ```

---

## 2. Core Prisma Schema Excerpt & Alignment

```prisma
model Car {
  id                   String                    @id @default(uuid())
  vendorId             String
  vendor               Vendor                    @relation(fields: [vendorId], references: [id])
  make                 String
  model                String
  year                 Int
  type                 CarCategory
  fuelType             FuelType
  seating              Int
  isAC                 Boolean                   @default(true)
  registrationNumber   String                    @unique
  photos               String[]
  pricePerKm           Decimal                   @db.Decimal(10, 2)
  pricePerDay          Decimal                   @db.Decimal(10, 2)
  pricePerHour         Decimal                   @db.Decimal(10, 2)
  isAvailable          Boolean                   @default(false)
  operationalStatus    VehicleOperationalStatus  @default(DRAFT)
  verificationStatus   VehicleVerificationStatus @default(PENDING)
  availableTripTypes   String[]                  @default(["SELF_DRIVE", "OUTSTATION"])
  pickupHubId          String?
  pickupHub            PickupHub?                @relation(fields: [pickupHubId], references: [id])
  serviceAreaId        String?
  serviceArea          ServiceArea?              @relation(fields: [serviceAreaId], references: [id])
  createdAt            DateTime                  @default(now())
  updatedAt            DateTime                  @updatedAt

  @@index([vendorId])
  @@index([pickupHubId])
  @@index([operationalStatus])
  @@index([verificationStatus])
}

model PickupHub {
  id             String    @id @default(uuid())
  vendorId       String?
  vendor         Vendor?   @relation(fields: [vendorId], references: [id])
  name           String
  address        String
  locality       String?
  city           String
  state          String?
  latitude       Float
  longitude      Float
  operatingHours String?
  contactPhone   String?
  isActive       Boolean   @default(true)
  cars           Car[]
  createdAt      DateTime  @default(now())
  updatedAt      DateTime  @updatedAt

  @@index([vendorId])
  @@index([city])
  @@index([isActive])
}

model VendorDepositPolicy {
  id               String   @id @default(uuid())
  version          Int      @unique
  isRequired       Boolean  @default(true)
  amount           Decimal  @db.Decimal(10, 2)
  currency         String   @default("INR")
  refundPolicy     String   @default("REFUNDABLE")
  description      String?
  refundConditions String?
  paymentProvider  String   @default("RAZORPAY")
  deadlineDays     Int      @default(14)
  isActive         Boolean  @default(true)
  effectiveFrom    DateTime @default(now())
  updatedBy        String
  createdAt        DateTime @default(now())
  updatedAt        DateTime @updatedAt

  @@index([isActive])
}
```
