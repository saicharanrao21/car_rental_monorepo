# DRIVEGO — PHASE 29.7 AUDIT DOCUMENT
## Customer Profile, KYC, Wallet & Loyalty UX Modernization Audit

---

### 1. Executive Summary & Objective

The objective of Phase 29.7 is to modernize the Customer Profile, KYC, Wallet, Loyalty, Referrals, Settings, and Support entry experiences into a cohesive, trustworthy, and premium financial and account center built entirely on the **DriveGo Design System (DDS)** foundation.

This audit reviews existing backend APIs, Flutter presentation layers, data contracts, security invariants, UX gaps, and provides the architectural blueprint for Phase 29.7.

---

### 2. Architectural Survey & Backend API Catalog

| Feature Area | Backend Controller / Service | Primary REST Endpoints | Data Models / Schema |
|---|---|---|---|
| **User Profile** | `UsersController` / `UsersService` | `PATCH /users/me`, `GET /auth/me`, `PATCH /users/me/fcm-token` | `User` (`name`, `email`, `phone`, `profilePhotoUrl`, `fcmToken`, `banned`, `createdAt`) |
| **KYC & Identity** | `KycController` / `KycService` | `GET /kyc/status`, `POST /kyc/submit`, `GET /admin/kyc/pending`, `PATCH /admin/kyc/:id/review` | `CustomerKyc` (`userId`, `licenceNumber`, `expiryDate`, `licenceFrontUrl`, `licenceBackUrl`, `status`, `rejectionReason`, `verifiedAt`) |
| **Customer Wallet** | `WalletsController` / `WalletsService` | `GET /wallet`, `GET /wallet/transactions?page=1&limit=20`, `GET /wallet/usable?bookingAmount=...`, `POST /wallet/deposit/create-order`, `POST /wallet/deposit/verify` | `Wallet` (`realBalance`, `promoBalance`, `status`), `WalletTransaction` (`amount`, `balanceType`, `direction`, `type`, `status`, `referenceId`, `description`, `createdAt`) |
| **Loyalty Program** | `LoyaltyController` / `LoyaltyService` | `GET /loyalty/account`, `GET /loyalty/transactions`, `GET /loyalty/tiers`, `POST /loyalty/redeem-to-wallet` | `LoyaltyAccount` (`pointsBalance`, `tier`, `lifetimePoints`, `expiringPoints`), `LoyaltyTransaction` (`points`, `type`, `description`, `createdAt`) |
| **Referrals** | `ReferralsController` / `ReferralsService` | `GET /referrals/my-code`, `GET /referrals/history`, `GET /referrals/eligibility`, `POST /referrals/apply-code` | `ReferralCode` (`code`, `refereeDiscount`, `referrerReward`), `Referral` (`referrerId`, `refereeId`, `status`, `bookingId`, `rewardPaidAt`) |
| **Support System** | `SupportTicketsController` / `SupportTicketsService` | `GET /support/tickets/my`, `POST /support/tickets`, `GET /support/tickets/:id`, `POST /support/tickets/:id/reply`, `POST /support/tickets/:id/close` | `SupportTicket` (`ticketNumber`, `subject`, `category`, `priority`, `status`, `messages`) |
| **Notifications** | `NotificationsController` / `NotificationsService` | `GET /notifications`, `PATCH /notifications/:id/read`, `PATCH /notifications/read-all` | `Notification` (`title`, `body`, `type`, `isRead`, `data`, `createdAt`) |

---

### 3. Existing UI & UX Gaps

1. **Profile Screen Hierarchy & Theming**:
   - Uses mixed styling with legacy `AppCard`, hardcoded colors (`Colors.grey`, `Colors.purple`, `Colors.amber`), and ad-hoc sizes instead of `DDSColors`, `DDSTypography`, `DDSSpacing`, and `DDSElevation`.
   - Lacks an authoritative Account Health summary card showing real profile completeness and KYC readiness.
2. **KYC Flow & Security**:
   - Displays raw Driving Licence numbers without masking (`DL1420110012345` instead of `DL••••••••2345`).
   - Lacks clear step guidance for image uploads, file preview, and rejection remediation instructions.
3. **Wallet Balance Financial Clarity**:
   - Real Cash balance and Promotional Balance need sharp visual separation with clear usage guidelines (Promotional balance non-withdrawable and subject to dynamic cart caps).
   - Deposit flow needs clear preset chips, transaction fee transparency, and instant ledger feedback.
4. **Loyalty & Rewards Club**:
   - Tier progression cards need clean DDS elevation, milestone badges (Bronze, Silver, Gold, Platinum), points conversion preview, and transparent expiry messaging.
5. **Refer & Earn Program**:
   - Needs 1-tap referral code clipboard copying, WhatsApp/SMS share triggers, and clear explanation of the 1st-booking completion criteria.
6. **Support & Roadside SOS**:
   - Needs structured category icons, direct emergency hotline trigger, and seamless ticket resolution tracking.

---

### 4. Financial & KYC Security Invariants

1. **No Client Financial Authority**: Wallet balances, promotional allowances, referral discounts, and loyalty conversion rates are strictly computed and verified on the server.
2. **PII & KYC Data Masking**: Driving Licence numbers and sensitive identifiers must be masked on overview screens.
3. **No Hardcoded Secrets or IDs**: No internal database UUIDs exposed to the UI; customer-friendly formatted references used throughout.
4. **Authoritative State Synchronization**: Riverpod providers invalidate and refetch on user actions (e.g. deposit, profile update, KYC submission, referral apply, points redeem).

---

### 5. Implementation & Modernization Plan

1. **Design System Integration**: Refactor Profile, KYC, Wallet, Loyalty, Referral, and Support views to strict DDS tokens (`DDSColors`, `DDSTypography`, `DDSSpacing`, `DDSRadius`, `DDSElevation`).
2. **Account Health & Verification Widget**: Implement a dynamic health badge displaying `Complete`, `KYC Pending Review`, `KYC Required`, or `Action Needed`.
3. **Wallet Financial Experience**: Modern balance card with Real vs Promo distinction, Add Money sheet with presets, and paginated transaction ledger.
4. **Loyalty Club Experience**: Tier visual cards, Points to Wallet conversion sheet, and earning rules explainer.
5. **Referral Experience**: Shareable code card, milestone reward progress, and referee promo activation.
6. **Support & Roadside Center**: Direct category FAQs, 1-tap ticket creation, and emergency SOS modal.
7. **Comprehensive Testing & Evidence**: Full Flutter test suite, static analysis, live Android emulator verification, 12 evidence screenshots, and a complete final PDF report.
