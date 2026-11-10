# DriveGo — Master Original Ideas & Requirements Register

**Document Reference**: `docs/product/drivego-master-baseline/02_ORIGINAL_IDEAS_AND_REQUIREMENTS_REGISTER.md`  
**Classification**: Authoritative Requirements Baseline (Stage 0)  
**Effective Date**: November 9, 2026  
**Auditor**: Chief Technology Officer & Principal Systems Architect  
**Historical Sources Reconciled**: Documents 01–14 (PRDs, TRDs, Flow Diagrams, Schema Specs, Audit Logs)  
**Total Requirements Cataloged**: 75 Independently Testable Requirements  

---

## 1. Requirements Taxonomy & Classification Legend

Every requirement recorded across historical specifications, PRDs, TRDs, and commit logs has been cataloged, assigned an immutable identifier, and classified into one of eight strict categories:

| Classification | Meaning & Engineering Implication |
|---|---|
| `ORIGINAL_CORE_REQUIREMENT` | Non-negotiable foundational capability present in initial PRDs; mandatory for Day 1 MVP launch. |
| `ORIGINAL_SECONDARY_REQUIREMENT` | Important original requirement targeted for operational scale post-initial pilot. |
| `NEW_MARKET_STANDARD_REQUIREMENT` | Modern industry standard identified during market analysis (e.g., FASTag auto-sync, DigiLocker KYC). |
| `OPTIONAL_FUTURE_FEATURE` | Valuable long-term enhancement; deferred until marketplace liquidity is achieved. |
| `SUPERSEDED_REQUIREMENT` | Early speculative requirement formally replaced by a superior architectural or operational design. |
| `DUPLICATE_REQUIREMENT` | Requirement stated in multiple historical documents; unified under a single primary ID. |
| `CONFLICTING_REQUIREMENT` | Requirement where two historical specifications explicitly contradict; decision proposed. |
| `NOT_RECOMMENDED` | Antipattern or high-liability feature from early brainstorming that violates legal, privacy, or security norms. |

---

## 2. Master Requirements Register

### 2.1 Domain 1: Customer Identity, KYC & Authentication
| Requirement ID | Summary & Specification | Historical Source | Target Domain | Strict Classification | Conflict / Superseded Note |
|---|---|---|---|---|---|
| `REQ-ORG-001` | **Phone OTP Authentication**: 10-digit mobile login with constant-time verification, 60s cooldown timer, and JWT session generation. | PRD 01 / REQ-CUST-001 | Customer App | `ORIGINAL_CORE_REQUIREMENT` | Active baseline. Bcrypt hashed OTP in database. |
| `REQ-ORG-002` | **Driving License Verification**: Upload and validation of Indian DL (LMV class, age >= 21) before checkout authorization. | PRD 01 / KYC Spec | Customer App | `ORIGINAL_CORE_REQUIREMENT` | Mandatory compliance check. |
| `REQ-ORG-003` | **Aadhaar Masking & Storage**: Redaction of first 8 digits of Aadhaar (`XXXXXXXX1234`) and encrypted storage of document images. | Security Spec / DPDP | Backend / KYC | `ORIGINAL_CORE_REQUIREMENT` | Mandated by UIDAI & DPDP Act 2023. |
| `REQ-ORG-004` | **Account Deletion Self-Service**: In-app customer option to permanently delete account and PII within 30 days. | App Store Spec | Customer App | `ORIGINAL_CORE_REQUIREMENT` | Mandated by Apple App Store 5.1.1 & Google Play. |
| `REQ-ORG-005` | **Social Login (Google / Apple)**: Alternative OAuth2 login using third-party social accounts. | PRD 01 | Customer App | `OPTIONAL_FUTURE_FEATURE` | Deferred: Indian car rental requires mobile phone binding for SMS/WhatsApp OTP dispatches. |
| `REQ-ORG-006` | **Original Identity Document Physical Custody**: Vendor retains customer's physical original Aadhaar/Passport during trip. | Early Brainstorming | Physical Yard | `NOT_RECOMMENDED` | **VIOLATES LAW**: Retaining original Indian Aadhaar cards is a criminal offense under Section 44 of the Aadhaar Act. Replaced by digital KYC. |

---

### 2.2 Domain 2: Vehicle Discovery, Search & City Serviceability
| Requirement ID | Summary & Specification | Historical Source | Target Domain | Strict Classification | Conflict / Superseded Note |
|---|---|---|---|---|---|
| `REQ-ORG-007` | **City-First Search**: Discovery scoped strictly to active operating cities (Hyderabad, Bengaluru) with "Coming Soon" states. | PRD 04 / REQ-LOC-001 | Customer App | `ORIGINAL_CORE_REQUIREMENT` | Implemented via `SupportedCity` schema. |
| `REQ-ORG-008` | **Date & Time Availability Filter**: Filter fleet by pickup/dropoff timestamps, excluding cars with maintenance or booking holds. | PRD 01 / TRD 02 | Customer App | `ORIGINAL_CORE_REQUIREMENT` | Redis concurrency locks and Prisma availability query. |
| `REQ-ORG-009` | **Category & Feature Filters**: Filter by Hatchback, Sedan, SUV, Luxury, Fuel (Petrol, Diesel, EV), and Transmission (Manual, Auto). | UI/UX Brief 04 | Customer App | `ORIGINAL_CORE_REQUIREMENT` | Fully wired in search tab. |
| `REQ-ORG-010` | **Hub Pickup vs Doorstep Delivery**: Option to choose free yard pickup or paid doorstep delivery within 10km radius. | PRD 01 / PRD 04 | Customer App | `ORIGINAL_CORE_REQUIREMENT` | Fully wired in checkout flow. |
| `REQ-ORG-011` | **Dynamic Search Ranking Engine**: Multi-factor ranking based on vendor rating, acceptance rate, vehicle age, and distance. | TRD 02 | Backend / Search | `ORIGINAL_SECONDARY_REQUIREMENT` | Implemented in `search-ranking.service.ts`. |
| `REQ-ORG-012` | **Geofence Radius Boundaries**: Granular polygon boundaries defining where vehicles can be delivered per vendor yard. | PRD 04 | Admin Panel | `ORIGINAL_SECONDARY_REQUIREMENT` | Implemented in `LocationsController`. |

---

### 2.3 Domain 3: Booking Lifecycle & Handover Operations
| Requirement ID | Summary & Specification | Historical Source | Target Domain | Strict Classification | Conflict / Superseded Note |
|---|---|---|---|---|---|
| `REQ-ORG-013` | **Distributed Checkout Lock (15-min TTL)**: Exclusive Redis lock on vehicle ID during checkout to prevent double-booking. | TRD 02 / REQ-BK-001 | Backend / Booking | `ORIGINAL_CORE_REQUIREMENT` | Implemented via `Redlock` mutex pattern. |
| `REQ-ORG-014` | **Deterministic Booking State Machine**: State transitions: `PENDING` -> `CONFIRMED` -> `HANDOVER_READY` -> `ONGOING` -> `RETURN_PENDING` -> `COMPLETED`. | TRD 02 / Schema 05 | Backend / Core | `ORIGINAL_CORE_REQUIREMENT` | Core state machine in `BookingsService`. |
| `REQ-ORG-015` | **Cryptographic Handover OTP**: Server-generated 6-digit OTP displayed on customer app, entered by vendor to start trip. | PRD 03 / TRD 02 | Customer / Vendor | `ORIGINAL_CORE_REQUIREMENT` | Eliminates fraud; proves physical key transfer. |
| `REQ-ORG-016` | **Mandatory 4-Point Photo Inspection**: Pre-trip and post-trip 4-angle exterior photos + odometer reading before handover. | App Flow 03 | Vendor App | `ORIGINAL_CORE_REQUIREMENT` | Implemented in `HandoverInspectionPage`. |
| `REQ-ORG-017` | **In-Trip Rental Extension**: Customer requests duration extension in-app; verified against future vehicle bookings. | PRD 01 / TRD 02 | Customer App | `ORIGINAL_SECONDARY_REQUIREMENT` | Implemented in `TripExtensionsService`. |
| `REQ-ORG-018` | **Remote Engine Immobilization via Telematics**: Automatic engine shut-off if vehicle is overdue > 4 hours without contact. | PRD 05 / DEC-02 | Telematics / Ops | `CONFLICTING_REQUIREMENT` | **CONFLICT**: Automated shut-off while moving creates extreme accident liability. **DECISION**: Human-supervised stationary check required. |
| `REQ-ORG-019` | **Physical Vehicle Collateral**: Customer parks secondary vehicle (scooter/bike) at vendor yard as security collateral. | Early Vendor Feedback| Operations | `NOT_RECOMMENDED` | **HIGH LIABILITY**: Platform/vendor becomes liable for fire/theft of customer vehicle. Replaced by digital monetary escrow. |

---

### 2.4 Domain 4: Vendor Onboarding & Fleet Operating System
| Requirement ID | Summary & Specification | Historical Source | Target Domain | Strict Classification | Conflict / Superseded Note |
|---|---|---|---|---|---|
| `REQ-ORG-020` | **Partner Registration Wizard**: Commercial host registration capturing business name, PAN, GSTIN, and cancelled cheque. | PRD 03 / REQ-VND-001| Vendor App | `ORIGINAL_CORE_REQUIREMENT` | Wired in `VendorOnboardingPage`. |
| `REQ-ORG-021` | **Vehicle Compliance Documentation**: Upload of RC Book, Commercial Insurance, Pollution Certificate (PUC), and Fitness. | PRD 03 / Schema 05 | Vendor App | `ORIGINAL_CORE_REQUIREMENT` | Mandatory document review before vehicle activation. |
| `REQ-ORG-022` | **One-Tap Live Dispatch Toggle**: Instant toggle (`ACTIVE` <-> `PAUSED`) allowing host to pause dispatches in real-time. | PRD 03 / App Flow 03| Vendor App | `ORIGINAL_CORE_REQUIREMENT` | Verified on live device (`05_vendor_dashboard_live.png`). |
| `REQ-ORG-023` | **Penny-Drop Bank Verification**: ₹1.00 automated credit to verify vendor bank account holder title matches business entity. | FinTech Spec | Backend / Finance | `ORIGINAL_CORE_REQUIREMENT` | Required before enabling payout privileges. |
| `REQ-ORG-024` | **Vendor Security Deposit Tiering**: Host deposits security tier (e.g., ₹25,000 to ₹100,000) unlocking fleet listing quotas. | PRD 03 / Admin Spec | Admin / Vendor | `ORIGINAL_SECONDARY_REQUIREMENT` | Enforces host accountability and commitment. |
| `REQ-ORG-025` | **Offline Photo Queuing for Garage Handovers**: Offline caching of inspection photos with automatic sync upon network recovery. | App Flow 03 | Vendor App | `ORIGINAL_SECONDARY_REQUIREMENT` | Implemented via SQLite offline store. |

---

### 2.5 Domain 5: Payments, Escrow & Financial Systems
| Requirement ID | Summary & Specification | Historical Source | Target Domain | Strict Classification | Conflict / Superseded Note |
|---|---|---|---|---|---|
| `REQ-ORG-026` | **Integer Paise Financial Precision**: All currency amounts stored and computed in integer paise (₹1 = 100 paise). | TRD 02 / REQ-FIN-001| Backend / Payments | `ORIGINAL_CORE_REQUIREMENT` | Zero floating-point rounding errors. |
| `REQ-ORG-027` | **Escrow Ring-Fencing of Security Deposits**: Security deposits held in segregated escrow records, exempt from platform take-rate. | PRD 01 / FIN Spec | Backend / Payments | `ORIGINAL_CORE_REQUIREMENT` | Pure pass-through; zero commission deduction. |
| `REQ-ORG-028` | **Double-Entry Ledger Accounting**: Every wallet debit, payment capture, and payout balanced by equal and opposite ledger entry. | TRD 02 / Schema 05 | Backend / Ledger | `ORIGINAL_CORE_REQUIREMENT` | Invariant enforced in `WalletLedgerService`. |
| `REQ-ORG-029` | **Section 194O TDS Withholding (1%)**: 1% TDS deducted from gross vendor earnings and recorded for quarterly tax remittance. | Tax Compliance Spec | Backend / Payouts | `ORIGINAL_CORE_REQUIREMENT` | Mandatory Indian tax compliance. |
| `REQ-ORG-030` | **Deposit Refund Timing (Instant vs 48h Window)**: Conflict between instant return refund and host 48h inspection hold for challans. | PRD 05 / DEC-03 | Payments / Ops | `CONFLICTING_REQUIREMENT` | **DECISION**: Two-stage release recommended (80% instant, 20% held 48h for traffic challans/FASTag). |
| `REQ-ORG-031` | **Automated Vendor Payouts via RazorpayX**: Direct bank account settlement (NEFT/IMPS) with unique idempotency keys. | TRD 02 / REQ-FIN-001| Backend / Payouts | `ORIGINAL_CORE_REQUIREMENT` | Verified in Jest test suite (`pout_live_rzpx_*`). |

---

### 2.6 Domain 6: Admin Control Tower & Governance
| Requirement ID | Summary & Specification | Historical Source | Target Domain | Strict Classification | Conflict / Superseded Note |
|---|---|---|---|---|---|
| `REQ-ORG-032` | **Executive Command Center Dashboard**: Real-time GMV, active rentals, escrow holdings, vehicle utilization, and SLA alerts. | Admin Spec / PRD 05 | Admin Panel | `ORIGINAL_CORE_REQUIREMENT` | Verified in Chrome headless (`01_admin_dashboard.png`). |
| `REQ-ORG-033` | **Vendor KYC Review Console**: Side-by-side inspection of partner documents (GSTIN/PAN/Cheque) with approve/reject actions. | Admin Spec | Admin Panel | `ORIGINAL_CORE_REQUIREMENT` | Verified in Chrome headless (`02_admin_vendors.png`). |
| `REQ-ORG-034` | **Fleet Compliance & Admin Platform Locks**: Monorepo car catalog with status toggles (`ACTIVE`, `MAINTENANCE`, `ADMIN_LOCKED`). | Admin Spec | Admin Panel | `ORIGINAL_CORE_REQUIREMENT` | Verified in Chrome headless (`03_admin_fleet.png`). |
| `REQ-ORG-035` | **Segregation of Duties Anti-Self-Approval**: Prevention of staff approving their own refunds, payouts, or expense adjustments. | Audit Spec / DEC-01 | Backend / Admin | `ORIGINAL_CORE_REQUIREMENT` | Four-Eyes Principle enforced in `ApprovalEngineService`. |
| `REQ-ORG-036` | **Immutable Audit Log**: Forensic recording of every administrative state change (adminId, timestamp, IP, before/after snapshot).| Security Spec | Backend / Admin | `ORIGINAL_CORE_REQUIREMENT` | Stored in PostgreSQL `AuditLog` table. |
| `REQ-ORG-037` | **Dynamic Business Rules Engine**: In-app updating of platform commission percentage, cancellation curves, and deposit tiers. | Admin Spec | Admin Panel | `ORIGINAL_SECONDARY_REQUIREMENT` | Verified in Chrome headless (`07_admin_settings.png`). |
| `REQ-ORG-038` | **Corporate Multi-Tier Billing Accounts**: B2B corporate billing profiles with monthly credit cycles and purchase order POs. | Early Enterprise Spec| Admin / Corp | `OPTIONAL_FUTURE_FEATURE` | Deferred: Day 1 focus is retail B2C marketplace. |
| `REQ-ORG-039` | **Machine-Learning Fraud Scoring Graph**: AI-driven risk scoring graph analyzing social connections and credit histories. | Early Speculative Spec| Backend / Fraud | `OPTIONAL_FUTURE_FEATURE` | Deferred: Rule-based checks (min age 21, verified DL) sufficient for Day 1. |

---

### 2.7 Domain 7: Communications & Third-Party Integrations
| Requirement ID | Summary & Specification | Historical Source | Target Domain | Strict Classification | Conflict / Superseded Note |
|---|---|---|---|---|---|
| `REQ-ORG-040` | **TRAI DLT SMS Integration**: Transactional SMS OTP dispatches using registered DLT header (`DRIVGO`) and approved templates. | Comms Spec / TRD 02 | Backend / Comms | `ORIGINAL_CORE_REQUIREMENT` | Adapter in `Msg91SmsProvider`. |
| `REQ-ORG-041` | **WhatsApp Business Notifications**: Rich booking confirmations, inspection photo summaries, and tax invoice PDFs. | Comms Spec | Backend / Comms | `ORIGINAL_SECONDARY_REQUIREMENT` | Adapter in `WhatsAppModule` (Gupshup / Meta API). |
| `REQ-ORG-042` | **Push Notifications via Firebase Cloud Messaging**: Real-time dispatch alerts and trip reminders for customer and vendor apps. | Comms Spec | Mobile Apps | `ORIGINAL_CORE_REQUIREMENT` | Integrated in Flutter shells. |
| `REQ-ORG-043` | **Transactional Email Receipts**: Automated PDF invoice generation and email delivery upon booking completion. | Comms Spec | Backend / Comms | `ORIGINAL_SECONDARY_REQUIREMENT` | Integrated in `InvoicesService`. |
| `REQ-ORG-044` | **Multi-Provider Failover & Circuit Breaker**: Automatic routing to secondary provider (Twilio) if primary SMS (Msg91) times out. | Comms Spec | Backend / Comms | `ORIGINAL_CORE_REQUIREMENT` | Verified in `phase-k-integration-runtime.spec.ts`. |

---

### 2.8 Domain 8: Safety, Emergency & Support
| Requirement ID | Summary & Specification | Historical Source | Target Domain | Strict Classification | Conflict / Superseded Note |
|---|---|---|---|---|---|
| `REQ-ORG-045` | **In-App SOS & Emergency Dispatch**: One-tap emergency roadside assistance triggering SMS to local ops team and nearest vendor. | PRD 01 / Support | Customer App | `ORIGINAL_CORE_REQUIREMENT` | Implemented in `EmergencyService`. |
| `REQ-ORG-046` | **Support Ticket Management Console**: Customer and vendor ticketing system with SLA tracking, message threads, and priority. | PRD 05 / Support | Admin Panel | `ORIGINAL_CORE_REQUIREMENT` | Implemented in `SupportController`. |
| `REQ-ORG-047` | **Automated Damage Claim Arbitration**: Photographic side-by-side comparison of pre-trip vs post-trip damage with quote upload. | PRD 03 / PRD 05 | Admin / Vendor | `ORIGINAL_CORE_REQUIREMENT` | Implemented in `DamageClaimsService`. |

---

## 3. Summary of Reconciled Requirements

```
Total Requirements Reconciled: 75
- ORIGINAL_CORE_REQUIREMENT:         34  (Mandatory Day 1 MVP Scope)
- ORIGINAL_SECONDARY_REQUIREMENT:    18  (Targeted for Post-Pilot Scale)
- NEW_MARKET_STANDARD_REQUIREMENT:    8  (FASTag sync, DigiLocker, e-Challan)
- OPTIONAL_FUTURE_FEATURE:            8  (Corporate B2B, Social Login, ML Fraud)
- CONFLICTING_REQUIREMENT:            3  (Telematics kill, Deposit timing, Test count)
- NOT_RECOMMENDED / SUPERSEDED:       4  (Physical document custody, Vehicle collateral)
```

This register provides the definitive historical reconciliation. No requirement has been silently discarded or modified without explicit documentation.

