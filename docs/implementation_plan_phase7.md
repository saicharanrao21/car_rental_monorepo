# PHASE 7 IMPLEMENTATION PLAN
**Scope:** Feature 23 (Referral Program) + Feature 24 (DriveGo Wallet) + Feature 25 (Loyalty Program)

## User Review Required

> [!IMPORTANT]
> **Proposed Defaults Needing CEO / Product Approval:**
> 1. **Referral Reward Values:**
>    - Referrer receives **₹250** Wallet Credit.
>    - Referee receives **₹250** Wallet Credit / Discount on their first booking.
>    - Minimum qualifying booking amount: **₹1,000**.
>    - Qualifying event: First booking reaching `COMPLETED` status.
> 2. **Loyalty Conversion Rate:**
>    - Base earning: **1 Point per ₹10 spent** on rental base fare (Tier multipliers: Bronze 1.0x, Silver 1.25x, Gold 1.5x, Platinum 2.0x).
>    - Point redemption rate: **2 Points = ₹1.00 Wallet Credit** (500 pts = ₹250).
>    - Points credit event: Upon booking reaching `COMPLETED` status.

---

## Proposed Implementation Steps

### Phase 7A: Wallet Financial Ledger Foundation (Feature 24)
1. **Prisma Schema & Migration:**
   - Add enums: `WalletStatus`, `LedgerEntryType`, `LedgerDirection`.
   - Add models: `Wallet`, `WalletLedgerEntry`.
   - Add relation on `User.wallet`.
   - Create migration: `20260816200000_add_wallet_referral_loyalty`.
2. **Backend `WalletsModule`:**
   - Implement `WalletsService`:
     - `getOrCreateWallet(userId: string, tx?: Prisma.TransactionClient)`
     - `creditWallet(walletId: string, amount: Decimal, type: LedgerEntryType, referenceType: string, referenceId: string, idempotencyKey: string, description: string, tx?: Prisma.TransactionClient)`
     - `debitWallet(walletId: string, amount: Decimal, type: LedgerEntryType, referenceType: string, referenceId: string, idempotencyKey: string, description: string, tx?: Prisma.TransactionClient)`
     - Pessimistic locking: `SELECT ... FOR UPDATE` inside `prisma.$transaction`.
     - Zero negative balance checks.
   - Implement `WalletsController` (Protected endpoints for customer & admin).
   - Write comprehensive unit tests in `wallet-ledger.spec.ts`.

### Phase 7B: Referral Program Implementation (Feature 23)
1. **Database Models:**
   - `ReferralCampaign`, `ReferralAttribution`, `User.referralCode`.
2. **Backend `ReferralsModule`:**
   - Code validation & attribution on signup.
   - Event hook on `BookingStatus.COMPLETED` to trigger qualification and wallet ledger credits.
   - Self-referral, device, and velocity fraud guards.
   - Write unit tests in `referral-program.spec.ts`.

### Phase 7C: Loyalty Program Implementation (Feature 25)
1. **Database Models:**
   - `LoyaltyTier`, `LoyaltyAccount`, `LoyaltyTransaction`.
2. **Backend `LoyaltyModule`:**
   - Points accrual on completed trips.
   - Tier progression & upgrade logic.
   - `POST /loyalty/redeem-to-wallet`: Atomic points debit + wallet ledger credit.
   - Write unit tests in `loyalty-program.spec.ts`.

### Phase 7D: Mobile Apps & Shared Models
1. **Shared Models (`packages/models`):**
   - `WalletModel`, `WalletLedgerEntryModel`, `ReferralModel`, `LoyaltyModel`.
2. **Customer App:**
   - `WalletPage`, `ReferralPage`, `LoyaltyPage`.
   - `PaymentStep`: DriveGo Wallet balance deduction toggle.
   - Unit tests in `wallet_model_test.dart`, `referral_test.dart`, `loyalty_test.dart`.

### Phase 7E: Admin Panel Management
1. **Admin Pages:**
   - `AdminWalletLedgerPage` & manual adjustment dialog.
   - `AdminReferralCampaignsPage`.
   - `AdminLoyaltyManagementPage`.

### Phase 7F: Full Regression & Database Benchmark Verification
1. Run backend tests (target: 45+ suites, 310+ unit tests).
2. Run Flutter tests across all packages.
3. Validate benchmark booking safety: `cmsu5sk3m000qgw1zaf9ftksz` = `CONFIRMED / PAID / NONE`.

---

## Verification Plan

### Automated Tests
- `npm test` in `car_rental_backend`
- `npm run build` in `car_rental_backend`
- `flutter test` in `packages/models`, `apps/customer_app`, `apps/vendor_app`, `apps/admin_panel`
- `flutter analyze lib` across all Flutter projects
- `node scratch/check_db_safety.js`
