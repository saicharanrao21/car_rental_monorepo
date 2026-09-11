# DRIVEGO — PHASE 7C IMPLEMENTATION PLAN
**Feature 25: DriveGo Loyalty / Rewards Program**

**Author:** Senior Principal Engineer, CTO, Security Architect, Payments Architect, QA Lead, Product Architect  
**Status:** **APPROVED & IN EXECUTION**  
**Target:** Feature 25 Production Implementation

---

## 1. System Architecture & Product Rules

### 1.1 Loyalty Tiers & Multipliers
- **Bronze:** 0 lifetime points threshold, 1.00x multiplier.
- **Silver:** 500 lifetime points threshold, 1.25x multiplier.
- **Gold:** 2,000 lifetime points threshold, 1.50x multiplier.
- **Platinum:** 5,000 lifetime points threshold, 2.00x multiplier.

### 1.2 Authoritative Point Earning
- **Formula:**
  $$\text{basePoints} = \lfloor \text{eligibleBaseFare} / 10 \rfloor$$
  $$\text{finalPoints} = \lfloor \text{basePoints} \times \text{tierMultiplier} \rfloor$$
- **Eligible Base Fare:** ONLY the authoritative base fare of the rental.
- **Strictly Excluded:** GST, security deposits, delivery/pickup fees, additional driver fees, protection/insurance fees, wallet top-ups, referral discount, cancellation fees, penalties, damage charges, refunds.
- **Event Trigger:** Authoritatively credited ONLY when booking reaches `COMPLETED`, booking is paid, not refunded, and not cancelled.
- **Deterministic Idempotency Key:** `loyalty_booking_${bookingId}`.

### 1.3 Tier Progression & Lifetime Points Preservation
- Tier is evaluated strictly from `lifetimePoints`.
- Redeeming points for wallet balance deducts `pointsBalance` but NEVER reduces `lifetimePoints` or downgrades the user's tier.

### 1.4 Wallet Redemption Integration
- **Conversion Rate:** 2 loyalty points = ₹1 DriveGo Promotional Wallet Credit (e.g. 500 points = ₹250).
- **Atomicity:** Single database transaction locks `LoyaltyAccount`, verifies balance, debits points, logs `LoyaltyTransaction`, credits `Wallet` (`PROMOTIONAL` bucket, `LOYALTY_CONVERSION` type), logs `WalletLedgerEntry`, and commits.
- **Zero Withdrawal:** Promotional credits cannot be withdrawn or used for security deposits.

---

## 2. Technical Roadmap

```
PHASE 7C-A: Database schema verification & tier initialization
PHASE 7C-B: Backend Loyalty Service & DTOs
PHASE 7C-C: Booking completion lifecycle hook in BookingsService
PHASE 7C-D: Wallet redemption atomic integration in WalletsService
PHASE 7C-E: Shared Dart Models (packages/models)
PHASE 7C-F: Customer App UI & Providers (apps/customer_app)
PHASE 7C-G: Admin Panel Management UI & Providers (apps/admin_panel)
PHASE 7C-H: Dedicated Backend Unit Tests & PostgreSQL Concurrency Tests
PHASE 7C-I: Full Monorepo Regression & Database Safety Validation
PHASE 7C-J: Completion Audit Documentation & Single Checkpoint Commit
```
