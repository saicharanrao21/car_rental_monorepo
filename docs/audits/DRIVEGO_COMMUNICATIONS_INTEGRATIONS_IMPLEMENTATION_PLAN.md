# DRIVEGO — COMMUNICATIONS & INTEGRATIONS IMPLEMENTATION & CLEANUP PLAN

**Document ID:** `PLAN-DRV-2026-005`  
**Date:** October 29, 2026  
**Lead Engineer:** Principal Enterprise Software Architect & Systems Lead  
**Scope:** Actionable implementation roadmap for hardening, consolidating, and connecting the Communications & Integrations modules.

---

## 1. Cleanup Matrix (KEEP / FIX / CONSOLIDATE / REMOVE / DEFER)

| Component / Capability | Category | Justification |
|---|:---:|---|
| **WhatsApp Business Console (`/whatsapp`)** | **KEEP** | Complete operational tool with summary, logs, templates, compose, resend, and timeline debugger. |
| **Event & Notification Rules (`/notification-rules`)** | **KEEP** | Persisted via `SystemConfig`, evaluated during lifecycle events, supports simulation and quiet hours. |
| **Communications Overview Telemetry** | **FIX** | Replace hardcoded mock numbers with real counts from `adminDeliveryStatsProvider` (`/admin/notifications/stats`). |
| **Delivery Logs Recipient PII & Retries** | **FIX** | Mask recipient phone/email (`+91 98765*****`), add debounce on manual retry, block retrying delivered messages. |
| **Workflow Automation Page (`/automation`)** | **FIX** | Replace hardcoded `_mockWorkflows` with real connection to `OperationsController` and `RentalAutomationService`. |
| **Integration Marketplace Branding** | **CONSOLIDATE** | Rebrand as **Integrations Hub**; focus on provider configuration, health checks, and circuit breakers. |
| **Push Notification Delivery Trace** | **CONSOLIDATE** | Retain push announcement composer; point delivery history links to unified `/delivery-logs`. |
| **Duplicate App-Store Marketplace Cards** | **REMOVE** | Remove consumer marketplace fluff (fake "Install Plugin" / "Buy Connector" cards) that do not represent active providers. |
| **Advanced Multi-Channel Journey Builder** | **DEFER** | Visual drag-and-drop workflow canvas deferred to Phase 2; declarative rules engine satisfies all current operational requirements. |

---

## 2. Dependency-Ordered Implementation Plan

### Step 1: Real Observability in Communications Overview (Priority 1)
- **Target File:** `apps/admin_panel/lib/features/communications/presentation/pages/communications_overview_page.dart`
- **Actions:**
  1. Watch `adminDeliveryStatsProvider` from `admin_notifications_providers.dart`.
  2. Map `overview.total` to 'Attempted', `overview.deliveryRate` to 'Delivered SLA', `overview.queued` to 'Queued Buffer', `overview.failed` to 'Failed Deliveries', and `overview.deadLetter` to 'Dead-Letter'.
  3. Add interactive click actions navigating to `/delivery-logs?status=FAILED` or `/delivery-logs?status=QUEUED`.

### Step 2: Delivery Logs PII Masking & Retry Hardening (Priority 2)
- **Target File:** `apps/admin_panel/lib/features/communications/presentation/pages/communication_delivery_logs_page.dart`
- **Actions:**
  1. Implement `_maskRecipient(String recipient)` function masking phone numbers (`+91 98765*****`) and emails (`r***@domain.com`).
  2. In the drawer retry action, disable the button if `delivery.status == 'DELIVERED'`, or if retry is currently in flight.
  3. Display success snackbar with execution feedback upon retry completion.

### Step 3: Workflow Automation Connection to Backend Services (Priority 3)
- **Target Files:**
  - `apps/admin_panel/lib/features/automation/presentation/pages/admin_automation_overview_page.dart`
  - `apps/admin_panel/lib/features/automation/presentation/widgets/automation_command_centre_widget.dart`
- **Actions:**
  1. Add an action button in the top toolbar: **"Trigger Maintenance Sweep"**, calling `POST /rental/automation/run` (or `/api/v1/operations/automation/run`).
  2. Display real sweeper outcomes: Expired quotes, expired unconfirmed reservations, detected overdue rentals, and pickup reminders.
  3. Update `automation_command_centre_widget.dart` to sync tab changes dynamically when top segment buttons are tapped.

### Step 4: Navigation Shell & Route Alignment (Priority 4)
- **Target Files:**
  - `apps/admin_panel/lib/core/widgets/admin_shell.dart`
  - `apps/admin_panel/lib/core/router/app_router.dart`
- **Actions:**
  1. Update sidebar item label from "Integration Marketplace" to "Integrations Hub".
  2. Verify all 8 routes (`/communications`, `/integrations`, `/notification-rules`, `/templates`, `/delivery-logs`, `/notifications`, `/whatsapp`, `/automation`) navigate directly without broken redirects.

### Step 5: Verification, Automated Testing & Documentation (Priority 5)
- **Actions:**
  1. Run `flutter test` across communications, notifications, rules, and automation suites.
  2. Run `npm test` across backend communications and notifications specs.
  3. Run `flutter analyze` to guarantee zero lint/type regressions.
  4. Create `docs/audits/DRIVEGO_COMMUNICATIONS_INTEGRATIONS_TEST_REPORT.md`.
