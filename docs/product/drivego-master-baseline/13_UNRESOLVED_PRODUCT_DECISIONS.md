# DriveGo — Unresolved Product & Governance Decisions Register

**Document Reference**: `docs/product/drivego-master-baseline/13_UNRESOLVED_PRODUCT_DECISIONS.md`  
**Classification**: Authoritative Governance Register (Stage 0)  
**Effective Date**: November 9, 2026  
**Auditor**: Chief Technology Officer & Principal Systems Architect  
**Objective**: Explicitly Formalize All Business, Legal, Safety, and Financial Decisions Requiring Platform Owner Sign-Off  

---

## 1. Executive Summary & Purpose

A robust engineering organization never silently chooses business policies or fabricates external legal determinations. When earlier specifications exhibit conflicting requirements or when operations introduce legal and financial liabilities, the Chief Technology Officer must explicitly frame the conflict, evaluate available options, propose a defensible recommendation, and hold the policy open until formal sign-off by the authorized stakeholder.

This register documents the **six critical governance decisions** governing the commercial launch of DriveGo.

---

## 2. Master Unresolved Decisions Register

### Decision DEC-01: Segregation of Duties Anti-Self-Approval Enforcement
- **Decision ID**: `DEC-01`
- **Affected Requirements**: `REQ-019`, `ApprovalEngineService`, `03_APPROVAL_AND_SEGREGATION_OF_DUTIES_MATRIX.md`.
- **The Issue**: Document 03 mandated that no staff member can authorize actions they personally created. Prior code allowed self-approval if the staff role matched the step requirements.
- **Impact**: High-risk financial fraud; an administrator could create a ₹25,000 refund and approve it unilaterally.
- **Available Options**:
  - *Option A (Strict Rejection)*: Strict enforcement: `requestedBy.id !== decidedBy.id` across all tiers.
  - *Option B (Threshold-Based)*: Allow self-approval for small amounts (<₹2,000); mandate two-person approval for >₹2,000.
  - *Option C (Super Admin Override)*: Allow self-approval only if staff holds `SUPER_ADMIN` role.
- **CTO Recommended Option**: **Option A**. The Four-Eyes Principle must be absolute for all financial mutations.
- **Status in Codebase**: **REMEDIATED & VERIFIED IN CODE**. Guard throws 400 Bad Request on self-approval. Awaiting formal business sign-off.
- **Accountable Stakeholder**: Head of Internal Audit & Platform Owner.

---

### Decision DEC-02: Overdue Vehicle Remote Engine Immobilization Protocol
- **Decision ID**: `DEC-02`
- **Affected Requirements**: `REQ-ORG-018`, `EmergencyService`, `SchedulingEngineService`.
- **The Issue**: Document 05 stated vehicles overdue > 4 hours are immobilized automatically via telematics. Document 09 SOP required manual manager authorization when the vehicle comes to a complete halt.
- **Impact**: Autonomously cutting off a vehicle's engine while it is traveling at high speed on a highway creates catastrophic collision and passenger fatality liability under Indian criminal law (Section 304A IPC / BNS).
- **Available Options**:
  - *Option A (Autonomous Cut-off)*: Script triggers telematics relay shut-off after +240 minutes overdue.
  - *Option B (Human-Supervised Stationary Gate)*: System flags overdue status and alerts Operations Manager. Manager verifies vehicle speed is 0 km/h (parked or idling) via telematics GPS before triggering remote immobilization.
  - *Option C (No Telematics Cut-off)*: Rely exclusively on physical field recovery and local police FIR.
- **CTO Recommended Option**: **Option B**. For passenger safety and legal defensibility, vehicle immobilization must **never** occur autonomously. It must require explicit human confirmation that the vehicle is stationary.
- **Status in Codebase**: Implemented to require manual supervisory dispatch.
- **Accountable Stakeholder**: VP Operations, Fleet Safety Lead & Legal Counsel.

---

### Decision DEC-03: Security Deposit Refund Timing — Instant vs Two-Stage Hold
- **Decision ID**: `DEC-03`
- **Affected Requirements**: `REQ-015`, `PaymentsService`, `DamageClaimsService`.
- **The Issue**: Document 05 stipulated immediate 100% refund at yard; Document 09 SOP allowed a 48-hour inspection hold to recover delayed traffic fines and toll charges.
- **Impact**: If 100% is refunded immediately, the host cannot recover municipal speeding e-Challans or FASTag tolls synced 12–24h later. If 100% is held for 48h, customer satisfaction drops.
- **Available Options**:
  - *Option A (Instant Full Refund)*: 100% deposit released immediately upon return photo sign-off.
  - *Option B (Two-Stage Release - 80% / 20%)*: **80% refunded instantly** at yard; **20% (or ₹1,500)** held in escrow for 48 hours to clear traffic camera challans and FASTag tolls, then auto-released.
  - *Option C (Full 48-Hour Hold)*: Entire deposit held for 48 hours post-trip, then auto-released.
- **CTO Recommended Option**: **Option B** (Two-Stage Release). Balances instant customer gratification with essential host asset protection.
- **Accountable Stakeholder**: Head of Product, Finance Controller & Vendor Relations Lead.

---

### Decision DEC-04: Fleet Vehicle Permitting — Commercial Yellow Plate vs White Plate
- **Decision ID**: `DEC-04`
- **Affected Requirements**: `REQ-ORG-021`, `CarsService`, `VendorOnboardingPage`.
- **The Issue**: The Motor Vehicles Act 1988 requires self-drive rental vehicles to hold commercial *Rent a Cab* permits (Yellow on Black plates). Peer-to-peer individual hosts frequently own private vehicles (White on Black plates).
- **Impact**: Operating private white-plate vehicles for commercial rental risks impoundment by Regional Transport Offices (RTOs), commercial insurance voiding in fatal accidents, and regulatory shutdown.
- **Available Options**:
  - *Option A (Commercial Only)*: Onboard exclusively commercial operators holding valid Rent a Cab permits for Day 1 launch.
  - *Option B (Hybrid / P2P Lease-Back)*: Allow private white-plate hosts to onboard via a legal short-term lease-back agreement to a licensed commercial entity.
  - *Option C (Unrestricted P2P)*: Onboard private white-plate vehicles and disclaim liability in terms of service (Zoomcar historical approach).
- **CTO Recommended Option**: **Option A for Day 1 Launch**. Launch in Hyderabad and Bengaluru exclusively with licensed commercial fleet operators. Explore Option B only after establishing regulatory liaison.
- **Accountable Stakeholder**: Corporate Legal Counsel & Platform Owner.

---

### Decision DEC-05: Multi-Factor Authentication (MFA) Scope for Staff Administrative Roles
- **Decision ID**: `DEC-05`
- **Affected Requirements**: `GATE-SEC-002`, `AdminStaffController`, `AuthService`.
- **The Issue**: Administrative staff accounts currently authenticate using email/password with Bcrypt hashing and active session revocation, but do not mandate RFC 6238 TOTP (Google Authenticator) on initial login.
- **Impact**: Administrative accounts could be vulnerable to credential stuffing if staff reuse weak passwords.
- **Available Options**:
  - *Option A (Password + Session Revocation)*: Current implementation; acceptable for internal staging.
  - *Option B (Mandatory SMS OTP)*: Require SMS OTP on admin login.
  - *Option C (RFC 6238 TOTP App)*: Mandate Google Authenticator / Microsoft Authenticator TOTP for `SUPER_ADMIN` and `FINANCE_CONTROLLER` roles before production cutover.
- **CTO Recommended Option**: **Option C**. Mandatory TOTP enforced prior to production launch.
- **Accountable Stakeholder**: Chief Technology Officer & Principal Security Architect.

---

### Decision DEC-06: Vendor Security Deposit Tiering — Mandatory Capital Commitment vs Zero-Deposit
- **Decision ID**: `DEC-06`
- **Affected Requirements**: `REQ-ORG-024`, `VendorsService`, `VendorDeposit`.
- **The Issue**: Document 03 required vendors to deposit a mandatory security tier (₹25,000 to ₹100,000) to unlock fleet listing quotas, ensuring partner commitment. Host acquisition leads argue this creates onboarding friction.
- **Impact**: Zero deposit lowers host acquisition barrier but increases risk of rogue hosts canceling confirmed bookings or absconding with customer vehicles. Mandatory deposit ensures host skin-in-the-game.
- **Available Options**:
  - *Option A (Mandatory Deposit Tiering)*: Require ₹25,000 for up to 5 cars; ₹50,000 for up to 10 cars; ₹100,000 for unlimited fleet.
  - *Option B (Performance-Based Waiver)*: Waive initial deposit for verified commercial operators with established physical garages; levy ₹5,000 rolling reserve from initial payouts.
  - *Option C (Zero Deposit)*: Completely eliminate vendor security deposit requirement.
- **CTO Recommended Option**: **Option B** (Performance-Based Waiver with Rolling Reserve). Maximizes host supply while protecting customer fulfillment.
- **Accountable Stakeholder**: Head of Growth, Head of Operations & Finance Controller.

---

## 3. Executive Decision Governance Sign-Off Table

| Decision ID | Domain | Recommended CTO Resolution | Business Owner Sign-Off Required | Impact on Current Codebase |
|---|---|---|---|---|
| **DEC-01** | Internal Security | Strict rejection of staff self-approval across all tiers | Yes (Formal Audit Record) | Already implemented & verified in code |
| **DEC-02** | Passenger Safety | Remote immobilization requires human verification of 0 km/h | Yes (Legal Approval) | Guard implemented in scheduling engine |
| **DEC-03** | Customer Escrow | Two-stage release: 80% instant at yard, 20% held 48h | Yes (Product & Finance Sign-Off) | Logic wired in payment engine |
| **DEC-04** | Regulatory / RTO | Commercial Yellow-Plate operators exclusively for Day 1 | Yes (Founder Decision) | Enforced via vehicle document review |
| **DEC-05** | Admin Security | Enforce RFC 6238 TOTP for Super Admin & Finance roles | Yes (CTO Approved) | Scheduled prior to Production Cutover |
| **DEC-06** | Vendor Supply | Waive deposit for physical yards; 5% rolling reserve | Yes (Operations / Growth Sign-Off) | Configurable via `SystemConfig` rules |

