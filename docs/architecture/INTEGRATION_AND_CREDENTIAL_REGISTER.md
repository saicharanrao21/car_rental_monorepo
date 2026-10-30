# DRIVEGO — INTEGRATION & CREDENTIAL REGISTER
## Third-Party Provider Architecture, Webhook Security & Fail-Closed Credential Management

> **Document Reference**: `docs/architecture/INTEGRATION_AND_CREDENTIAL_REGISTER.md`  
> **Classification**: Technical Infrastructure Standard  
> **Status**: APPROVED — PRODUCTION BLUEPRINT  
> **Author**: DriveGo DevOps & Cloud Security Architecture Group  

---

## 1. THIRD-PARTY INTEGRATION INVENTORY

```
┌────────────────────────────────────────────────────────────────────────┐
│                   INTEGRATION & PROVIDER REGISTRY                      │
├──────────────────┬──────────────────────┬──────────────────────────────┤
│ SERVICE          │ PRIMARY PROVIDER     │ BUSINESS PURPOSE             │
├──────────────────┼──────────────────────┼──────────────────────────────┤
│ Customer Payment │ Razorpay Standard    │ Cards, UPI, NetBanking pay   │
├──────────────────┼──────────────────────┼──────────────────────────────┤
│ Vendor Payouts   │ RazorpayX IMPS/NEFT  │ Automated weekly payouts     │
├──────────────────┼──────────────────────┼──────────────────────────────┤
│ Object Storage   │ Cloudflare R2 / S3   │ KYC docs, inspection photos  │
├──────────────────┼──────────────────────┼──────────────────────────────┤
│ Transactional WA │ Meta WhatsApp Cloud  │ Handover OTPs, booking info  │
├──────────────────┼──────────────────────┼──────────────────────────────┤
│ Statutory SMS    │ MSG91 (DLT India)    │ Fallback OTPs & alert SMS    │
├──────────────────┼──────────────────────┼──────────────────────────────┤
│ Tax Invoicing    │ SendGrid Email       │ PDF invoices & legal MSAs    │
├──────────────────┼──────────────────────┼──────────────────────────────┤
│ Real-Time Push   │ Firebase (FCM)       │ Background driver alerts     │
├──────────────────┼──────────────────────┼──────────────────────────────┤
│ Cache & Queues   │ Redis 7 / BullMQ     │ Concurrency locks & outbox   │
└──────────────────┴──────────────────────┴──────────────────────────────┘
```

---

## 2. WEBHOOK SECURITY & IDEMPOTENCY CONTROLS

All incoming third-party webhooks enforce cryptographic signature verification before body parsing:
1. **Razorpay Webhooks (`POST /api/v1/payments/webhook`)**:
   - Signature verified using HMAC-SHA256 with `RAZORPAY_WEBHOOK_SECRET`.
   - Event deduplication: Webhook event ID checked against `ProcessedWebhookEvent` table. Duplicate delivery attempts are acknowledged with HTTP 200 without re-executing transactions.
2. **WhatsApp Webhooks (`POST /api/v1/whatsapp/webhook`)**:
   - Verification token validated against `META_WA_VERIFY_TOKEN`.
   - Message delivery and read receipts recorded with provider message ID matching.

---

## 3. FAIL-CLOSED CREDENTIAL MANAGEMENT ARCHITECTURE

To prevent catastrophic runtime failures or credential leaks:
1. **Zero Hardcoded Secrets**: No API keys, passwords, or secrets exist in version control.
2. **Boot-Time Fail-Closed Validation**:
   - The application invokes `SystemConfigValidator.validateProductionConfiguration()` during bootstrap.
   - If any required production secret is missing or malformed, the process exits immediately with a descriptive fatal log, preventing degraded operation.
3. **Template Documentation**:
   - The authoritative environment template is [`car_rental_backend/.env.example`](file:///d:/Flutter/car_rental_monorepo/car_rental_backend/.env.example), documenting variable names, types, and sandbox fallbacks without containing live credentials.

---
*Ratified by DriveGo DevOps & Cloud Security Architecture Group.*

