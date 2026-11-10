# DriveGo — Vehicle Verification, Ownership Audit & Admin Approval Specification

**Document Reference**: `docs/product/DRIVEGO_VEHICLE_VERIFICATION_AND_APPROVAL_SPEC.md`  
**Classification**: Authoritative Fleet Governance & Compliance Specification  
**Effective Date**: November 9, 2026  
**Author**: Chief Technology Officer, Compliance Specialist & QA Lead  
**Repository**: `https://github.com/saicharanrao21/car_rental_monorepo`  
**Git Baseline Commit**: `b87cfe90527c801172529290b96f3d7c0200b941` (Branch: `main`)  
**Status**: APPROVED FOUNDER FLEET AUDIT SPECIFICATION — IMPLEMENTATION STATUS: PENDING EXPLICIT FOUNDER APPROVAL  

---

> [!CAUTION]
> **Implementation Authorization Directive**: This specification defines vehicle audit rules and compliance criteria. **NO IMPLEMENTATION AUTHORIZATION HAS BEEN GRANTED**. All engineering implementation remains strictly `PENDING EXPLICIT FOUNDER APPROVAL`.

---

## 1. Executive Summary & Non-Negotiable Directives

```
========================================================================================
            FOUNDER-CONFIRMED DIRECTIVE: RIGOROUS FLEET OWNERSHIP AUDIT
========================================================================================
1. 100% DEALER-OWNED FLEET ONLY:
   Every listed vehicle must be legally owned by the registered dealer business entity
   or its verified sole proprietor.
   STRICTLY EXCLUDED: Leased vehicles, subleased vehicles, managed vehicles, consignment
   vehicles, third-party-owned vehicles, and privately hosted vehicles.
   THERE ARE ZERO EXCEPTIONS FOR LEASES WITH SUBLEASE AUTHORIZATIONS.
2. NO UNIVERSAL HARDCODED VEHICLE AGE:
   There is NO founder-approved universal age limit (no hardcoded 5-year or 7-year cap).
   Vehicle eligibility is assessed individually by Admin based on condition, roadworthiness,
   RC classification, insurance coverage, fitness certification, and inspection evidence.
3. MANDATORY SIDE-BY-SIDE ADMIN AUDIT:
   Admin Control Tower must provide an audit interface comparing:
   - Registered dealer / business / proprietor name.
   - RC registered owner name.
   - Vehicle registration plate number.
   - Submitted ownership evidence (RC, invoice, tax receipt).
   - Supporting statutory documents.
   Any mismatch must enter manual review rather than automated approval.
4. IMMUTABLE DECISION AUDIT TRAIL:
   Every review action must permanently record reviewer admin ID, timestamp, decision,
   reason, supporting evidence, and resubmission instructions.
========================================================================================
```

---

## 2. Vehicle Verification & Audit Workflow

```mermaid
flowchart TD
    D1[Dealer Adds Vehicle & Uploads Documents\nRC, Commercial Insurance, Fitness, Permit, Photos] --> S1[System Pre-Flight Validation\nRegex Check, Plate Format, VAHAN API Lookup]
    
    S1 --> S2{Automated Name & Class Match?}
    S2 -->|Clean Match| Q1[Admin Verification Queue\nStatus: PENDING_VERIFICATION]
    S2 -->|Mismatch / Defect| Q2[Manual Investigation Queue\nFlagged: TITLE_MISMATCH_SUSPECTED]
    
    Q1 & Q2 --> Admin[Admin Compliance Officer Review]
    
    Admin -->|Inspects 5 Comparison Dimensions| Review{Officer Evaluation}
    
    Review -->|All Criteria Passed| Appr[Approved & Activated\nStatus: ACTIVE | Searchable: YES]
    Review -->|Deficiency / Blurry Image| Info[Additional Info Required\nStatus: DRAFT | Partner Resubmission]
    Review -->|Unowned / Leased / Disqualified| Rej[Rejected\nStatus: REJECTED | Searchable: NO]

    Appr & Info & Rej --> Log[(VehicleAuditLog\nReviewer, Timestamp, Decision, Reason, Evidence)]
```

---

## 3. The 5-Point Administrative Audit Interface

In the Admin Control Tower ([`/admin/fleet/:id`](file:///D:/Flutter/car_rental_monorepo/apps/admin_panel/lib/core/widgets/admin_shell.dart)), the compliance officer is presented with a structured side-by-side audit workspace:

```
+---------------------------------------------------------------------------------------------------+
|                        ADMIN CONTROL TOWER: VEHICLE TITLE & COMPLIANCE AUDIT                      |
+------------------------------------+--------------------------------------------------------------+
| Audit Dimension                    | Verification Standard & Comparison Target                    |
+------------------------------------+--------------------------------------------------------------+
| 1. Registered Entity Match         | Dealer Legal Name / Proprietor Name vs RC Registered Owner.  |
| 2. Registration Plate & VIN        | Physical Plate in Photos vs RC Registration No vs VIN Chassis.|
| 3. Commercial Vehicle Category     | Must state "Motor Cab" / "Tourist Taxi". Private LMV rejected.|
| 4. Commercial Insurance & Fitness  | Valid Rent-a-Cab self-drive policy + Form 38 Fitness / RC fitness validity (conditional on state/vehicle class rules).|
| 5. Physical Vehicle Condition      | 5-point photos: Body integrity, tire condition, cockpit, odo.|
+------------------------------------+--------------------------------------------------------------+
```

### 3.1 Strict Handling of Title Mismatches
1. **Identical Match**: RC Owner Name exactly matches the registered legal entity or the verified sole proprietor on file -> Officer verifies commercial class and proceeds.
2. **Proprietorship Variant**: RC is registered under individual name $X$, while dealer business is "$X$ Car Rentals" -> Officer verifies proprietor PAN / Aadhaar matches individual name $X$. If verified, approved as a sole proprietorship fleet asset.
3. **Entity Discrepancy (e.g. Director Personal Car or Third-Party Car)**:
   - If RC is registered to an individual director/shareholder rather than the private limited company, or to an unrelated third party: **AUTOMATICALLY FLAGGED AND HELD**.
   - The vehicle cannot be approved under dealer-owned policy unless formally transferred to the entity name or verified by legal counsel under approved title criteria.
   - Leased vehicles with "sublease NOCs" or "management agreements" are **STRICTLY REJECTED**.

---

## 4. Vehicle Age & Roadworthiness Assessment Framework

In accordance with founder decisions, vehicle eligibility is not restricted by a blunt, hardcoded age cut-off. Instead, Admin officers evaluate the vehicle's operational fitness:

### 4.1 Evaluation Criteria for Vehicle Approval
1. **Mechanical Fitness & Safety**: Valid RTO Form 38 Certificate of Fitness or statutory fitness period endorsed on commercial RC confirming mechanical and structural integrity (Conditional: General statutory provision per Section 56 of the Motor Vehicles Act, 1988 / Rule 62 CMVR; operational applicability to specific self-drive cab classes and launch state pending written transport counsel confirmation).
2. **Speed Limiting Compliance**: Valid Speed Governor calibration certificate (Tier B: Prescribed under Rule 118 CMVR 1989; state-level cab enforcement pending legal counsel verification).
3. **Emissions Compliance**: Valid government Pollution Under Control (PUC) certificate with QR verification (Tier A: Statutory requirement).
4. **Visual & Cabin Condition**: Clean, undamaged exterior body panels; functional air conditioning; unstained interior upholstery; functional seatbelts across all seating positions (Tier C: Operational requirement).
5. **Mileage & Wear**: Realistic odometer reading corroborated by maintenance service records (Tier C: Operational requirement).

> [!CAUTION]
> **Safety Over Age**: The absence of a hardcoded age cap does NOT permit the approval of any vehicle that fails statutory emissions, mechanical fitness, or passenger safety requirements. Any vehicle exhibiting structural rust, damaged airbags, bald tires, or failing RTO inspection is rejected immediately regardless of age.

---

## 5. Audit Logging & State Transitions

Every transition of a vehicle's verification status creates an immutable entry in `model VehicleAuditLog`:

```prisma
model VehicleAuditLog {
  id               String                    @id @default(cuid())
  carId            String
  car              Car                       @relation(fields: [carId], references: [id], onDelete: Restrict)
  actorId          String                    // Admin user ID
  actorRole        Role                      @default(ADMIN)
  action           String                    // SUBMITTED, APPROVED, REJECTED, INFO_REQUESTED, SUSPENDED
  fromStatus       VehicleOperationalStatus?
  toStatus         VehicleOperationalStatus
  reason           String?                   // Structured rejection or info reason
  evidenceNotes    String?                   // Officer review notes
  checklistResults Json?                     // Captured 5-point checklist
  resubmissionReqs String?                   // Specific instructions sent to partner
  timestamp        DateTime                  @default(now())

  @@index([carId])
  @@index([actorId])
  @@index([timestamp])
}
```

