# DriveGo Self-Drive Mobility Marketplace — Promotions & Campaign Engine

**Document Reference:** `ENG-PROM-06`  
**Version:** 2.0.0-PROD  
**Author:** DriveGo Principal Software Architect & Head of Growth  
**Scope:** Marketing Campaigns, Coupon Engine, Discounts, Budgeting, and Financial Attribution  
**Status:** Approved for Implementation

---

## 1. Architectural Distinction: Campaign vs Discount Application

DriveGo separates the **Marketing Campaign Definition** from the **Transaction-Level Discount**:
- **Campaign / Promotion:** An administrative growth entity defining targeting rules, eligibility criteria, date windows, discount parameters, funding source, and budget caps.
- **Applied Discount:** An immutable financial calculation executed server-side at quote generation, validated at checkout, and recorded as a journal entry in the platform ledger upon booking confirmation.

---

## 2. Supported Promotion Scopes

| Promotion Scope | Targeted Audience / Inventory | Trigger Mechanism | Funding Attribution |
|:---|:---|:---|:---|
| **Platform-Wide** | All eligible customers and vehicles across all cities | Automatic or banner click | Platform-funded (DriveGo Growth Budget) |
| **City / Service Area** | Bookings originating in a specific city (e.g. Hyderabad Launch) | Automatic based on pickup location | Platform-funded or Co-op city marketing |
| **Specific Vendor** | All vehicles belonging to an enrolled vendor partner | Automatic on partner's listings | Vendor-funded (deducted from payout) |
| **Specific Vehicle** | Targeted listing discount for slow-moving inventory | Automatic on targeted car ID | Vendor-funded or Platform-subsidized |
| **Customer Segment** | First-time renters, high-frequency loyalty members | Server-evaluated customer segment | Platform-funded |
| **Coupon Code** | Customers entering explicit promo code (e.g. `DRIVEGO500`) | Manual code entry in checkout | Platform or Vendor based on rule |
| **Referral Reward** | Referrer and referee trip credits | Referral link / code verification | Platform-funded |

---

## 3. Deterministic Precedence, Stacking & Calculation Rules

### 3.1 Precedence Hierarchy
When a booking matches multiple active campaigns, the engine evaluates eligibility using the following deterministic rule:
1. **Explicit Coupon Code:** If customer enters an active coupon code, it takes precedence.
2. **Vehicle-Level Discount:** If the vendor configured a specific vehicle discount (e.g. ₹500 off), it applies next.
3. **Automatic City / Platform Promotion:** Evaluated if stacking is explicitly allowed by campaign rules.
4. **Default Stacking Invariant:** By default, promotions **do NOT stack** unless both campaigns explicitly carry `allowStacking: true`. If multiple non-stackable promotions match, the system selects the single promotion offering the **maximum savings** to the customer.

### 3.2 Maximum Discount Cap & Minimum Booking Value
Every campaign must define:
- `minBookingAmount`: Minimum gross trip value required to trigger discount.
- `maxDiscountAmount`: Upper cap in INR preventing extreme discounts on luxury vehicles.
- `discountType`: `PERCENTAGE` (e.g. 15% off) or `FLAT` (e.g. ₹500 off).

---

## 4. Concurrency Control & Budget Consumption

To prevent promotional leakage during peak marketing blitzes (e.g. Diwali campaign):
1. **Atomic Counter Decrement:** Campaign redemption count and consumed budget are updated inside a PostgreSQL transaction with optimistic row locking:
   ```sql
   UPDATE "Coupon"
   SET "currentRedemptions" = "currentRedemptions" + 1,
       "consumedBudget" = "consumedBudget" + :discountAmount
   WHERE "id" = :couponId 
     AND "isActive" = true 
     AND ("maxRedemptions" IS NULL OR "currentRedemptions" < "maxRedemptions")
     AND ("totalBudget" IS NULL OR "consumedBudget" + :discountAmount <= "totalBudget");
   ```
2. **Lock Release on Failure:** If booking payment fails or checkout expires, the reservation counter is decremented automatically.
3. **Double-Entry Financial Attribution:**
   - Platform-funded discounts are debited to `Expense:MarketingPromotions` and credited to `Liability:CustomerPayable`.
   - Vendor-funded discounts are debited to `Receivable:VendorPromotion` and settled against the vendor's gross payout.

