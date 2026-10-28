# DriveGo — Database & Prisma Migration Safety Plan (Phase 4)

**Audit Execution Date:** October 28, 2026  
**Auditor:** Database Administrator & Infrastructure Lead  
**Scope:** PostgreSQL Engine, Prisma 6.2 ORM, 35 Migration Files, Schema Baseline, and Data Integrity  

---

## 1. Investigation of Historical Prisma P3005 Condition

### Background & Root Cause Analysis
In earlier development iterations, Prisma CLI returned an error:
`P3005: The database schema is not empty. Read more about how to baseline an existing production database: https://pris.ly/d/migrate-baseline`

This condition occurs when:
1. PostgreSQL contains existing tables (created manually, via raw SQL scripts, or via Docker initialization).
2. The `_prisma_migrations` metadata tracking table is absent or lacks entries for historical migrations.
3. Running `prisma migrate dev` or `prisma migrate deploy` encounters an existing table (e.g. `User`) and aborts to prevent catastrophic data loss.

### Current Verification Status
- **Verification on Clean Database (`car_rental` on port 5432):**
  - All **35 sequential migrations** were applied from scratch using `prisma migrate deploy`.
  - Result: **35 applied successfully in 8.1 seconds with 0 errors**.
- **Schema Drift Check:**
  - Command: `npx prisma migrate diff --from-schema-datasource ... --to-schema-datamodel ... --exit-code`
  - Result: **Exit Code 0: `No difference detected.`**
- **Conclusion:** The migration SQL files in `car_rental_backend/prisma/migrations/` represent a mathematically complete, valid schema definition with **zero drift** from `schema.prisma`.

---

## 2. Inventory of Sequential Migrations (35 Migrations)

| Migration Index | Directory Name | Scope & Changes Applied |
|---|---|---|
| 01 | `20260709131407_init` | Initial core tables: `User`, `Car`, `Booking`, `Payment`, `Review` |
| 02 | `20260709132408_add_password_hash` | Adds `passwordHash` to `User` for admin authentication |
| 03 | `20260710083129_add_fcm_token` | Push notification device token registration |
| 04 | `20260720104240_add_car_relation_to_documents` | Foreign key relation from `Document` to `Car` |
| 05 | `20260724045005_phase_a_feature_foundation` | Multi-role platform foundations (`Vendor`, `CommissionConfig`) |
| 06 | `20260724090843_make_vendor_user_id_nullable` | Decouples individual users from company vendors |
| 07 | `20260806101558_add_supported_cities_and_enabled_trip_types` | Multi-city operations and trip type definitions |
| 08 | `20260814060900_add_refund_and_cancellation_tracking` | Cancellation policy, refund states, fee calculations |
| 09 | `20260814120000_add_vehicle_inspections_and_handover_otps` | Pre-trip and post-trip digital vehicle inspections, handover OTPs |
| 10 | `20260814180000_add_security_deposits_and_damage_claims` | Security deposits, damage claim reporting, deposit hold states |
| 11 | `20260814193000_add_unique_active_damage_claim_index` | Prevents duplicate active damage claims per booking |
| 12 | `20260815183500_add_unique_razorpay_order_id` | Enforces database uniqueness on `razorpayOrderId` |
| 13 | `20260816090219_add_coupons_and_booking_coupon_fields` | Promotional coupons, discount types, usage limits |
| 14 | `20260816093405_add_customer_kyc_and_booking_statuses` | Customer KYC verification states, driving license validation |
| 15 | `20260816113000_add_deposit_rules_and_invoices` | Tiered security deposit rules and downloadable tax invoices |
| 16 | `20260816120000_add_trip_extensions_delivery_additional_drivers` | Mid-trip extensions, doorstep delivery, additional drivers |
| 17 | `20260816150000_add_support_emergency_protection` | Emergency SOS assistance, support ticket management |
| 18 | `20260816200000_add_wallet_referral_loyalty` | Customer wallet credits, referral rewards, tier-based loyalty points |
| 19 | `20260817140000_add_whatsapp_messages` | WhatsApp template messaging logs and delivery status |
| 20 | `20260819130000_add_configurable_mileage_packages` | Mileage packages (Limited vs Unlimited km) |
| 21 | `20260902180000_add_location_and_fulfillment_persistence` | Geofenced pickup hubs, return hubs, GPS tracking logs |
| 22 | `20260906120000_add_enum_values` | Extends booking, payment, and operational enums |
| 23 | `20260906120001_add_quotes_holds_refunds_and_audit_ledger` | Immutable platform ledger entries, reservation hold states |
| 24 | `20260908000000_add_service_areas_and_vendor_coverage` | Vendor operating zones and locality polygons |
| 25 | `20260908100000_add_vendor_onboarding_and_security_deposit` | Multi-step vendor registration, onboarding deposits |
| 26 | `20260908200000_add_vendor_fleet_operations_and_availability` | Fleet operational states (CLEANING, MAINTENANCE, ON_RENT) |
| 27 | `20260909120000_add_enterprise_integration_runtime_and_incidents` | Outbound integration incident tracking and circuit breakers |
| 28 | `20260909160000_add_provider_control_plane_governance` | Provider routing rules and gateway configuration |
| 29 | `20260909180000_add_rental_core_and_allocations` | Vehicle allocation strategies (`EXACT_VEHICLE`, `CLASS_MODEL`) |
| 30 | `20260909200000_add_marketplace_checkout_and_promotions` | Checkout sessions and campaign bundling |
| 31 | `20260910100000_add_enterprise_fulfillment_and_marketplace_operations` | Handover checklists and SLA escalation |
| 32 | `20260910140000_add_enterprise_ledger_and_corporate_employee_hierarchy`| Double-entry corporate credit accounts and employee bookings |
| 33 | `20260919120000_add_growth_campaigns_and_analytics` | Campaign attribution, referral tracking, platform analytics |
| 34 | `20260919130000_add_chat_and_waitlist` | In-app messaging tables and city demand waitlists |
| 35 | `20260919140000_add_social_auth` | OAuth accounts for Google and Apple sign-in |

---

## 3. Safe Production Baselining & Deployment Protocol

When deploying to an existing production or staging PostgreSQL instance that may already contain tables:

### Step 1: Pre-Flight Safety Verification
```bash
# 1. Take a full snapshot backup before attempting any schema operations
pg_dump -h <host> -p 5432 -U <user> -d <dbname> -Fc -f "drivego_pre_migration_backup_$(date +%Y%m%d%H%M%S).dump"

# 2. Check current migration state without applying
npx prisma migrate status --schema=car_rental_backend/prisma/schema.prisma
```

### Step 2: Baselining Pre-Existing Databases (If P3005 is encountered)
If the database contains tables from a prior direct SQL setup without Prisma history:
```bash
# Mark all prior applied migrations as applied without re-running the SQL
npx prisma migrate resolve --applied 20260709131407_init --schema=car_rental_backend/prisma/schema.prisma
# Repeat for migrations that were already executed in the target database
```

### Step 3: Normal Forward Deployment
For fresh environments or properly baselined targets:
```bash
# Execute only unapplied migrations safely inside transactions
npx prisma migrate deploy --schema=car_rental_backend/prisma/schema.prisma
```

### Step 4: Post-Migration Invariant Verification
Run the database invariant check script to verify ledger balance and orphan records:
```bash
npm --prefix car_rental_backend run dr:drill
```
Expected output:
- `isLedgerBalanced: true`
- `orphanBookings: 0, orphanCars: 0, orphanPayments: 0`
- `status: VERIFIED`
