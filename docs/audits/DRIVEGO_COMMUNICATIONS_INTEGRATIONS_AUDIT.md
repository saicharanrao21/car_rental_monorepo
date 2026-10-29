# DRIVEGO — COMMUNICATIONS & INTEGRATIONS FORENSIC AUDIT MATRIX

**Document ID:** `AUD-DRV-2026-009`  
**Date:** October 29, 2026  
**Auditors:** Senior Software Architect, Messaging Infrastructure Engineer, Security Engineer & QA Lead  
**Scope:** Forensic evaluation of the 8 visible modules under Communications & Integrations in the Super Admin Control Tower:
1. Communications Overview (`/communications`)
2. Integration Marketplace (`/integrations`)
3. Event & Notification Rules (`/notification-rules`)
4. Message Templates (`/templates`)
5. Delivery Logs & Retries (`/delivery-logs`)
6. Push Notifications (`/notifications`)
7. WhatsApp Messaging (`/whatsapp`)
8. Workflow Automation (`/automation`)

---

## 1. Classification Standard

Each capability is classified under one of the 10 forensic status codes:
- **A. IMPLEMENTED AND VERIFIED:** Complete end-to-end functionality backed by real persistence, runtime execution, and passing automated tests.
- **B. IMPLEMENTED BUT UNVERIFIED:** Full code exists across layers, but lacks automated test coverage.
- **C. PARTIALLY IMPLEMENTED:** Partial workflow exists; critical steps (such as error recovery or authorization) are incomplete.
- **D. FRONTEND ONLY:** UI exists, but backend endpoint or persistence is absent.
- **E. BACKEND ONLY:** Backend service/endpoint exists, but admin panel UI is absent.
- **F. MOCKED OR HARDCODED:** UI or service relies on fake mock data or static strings rather than operational data.
- **G. BROKEN:** Code exists but throws runtime exceptions or fails build/analysis.
- **H. DUPLICATED:** Redundant implementations exist in multiple locations competing for ownership.
- **I. UNNECESSARY OR OBSOLETE:** Feature is dead code, unused, or out of scope.
- **J. NOT IMPLEMENTED:** Required by specification, but no code exists.

---

## 2. Module-by-Module Forensic Audit

### 2.1 Module 1: Communications Overview
- **Business Responsibility:** Real-time health, buffer status, and delivery observability across WhatsApp, SMS, Email, Push, and Voice.
- **Route & Screen:** `/communications` -> `CommunicationsOverviewPage` (`apps/admin_panel/lib/features/communications/presentation/pages/communications_overview_page.dart`).
- **Backend Endpoints:**
  - `GET /admin/notifications/stats` (`NotificationsController.getDeliveryStats`)
  - `GET /api/v1/integrations/admin/communication-ecosystem/overview` (`AdminIntegrationsController.getCommunicationEcosystemOverview`)
- **Database Models:** Prisma `Notification`, `NotificationDelivery`, `CommunicationMessage`.
- **Finding:** The page provides navigation shortcuts to `/notification-rules`, `/templates`, and `/delivery-logs`, and embeds `CommunicationEcosystemWidget`. However, the top telemetry cards (`_buildTelemetrySummary`) display hardcoded strings (`1,482,900 attempted`, `99.82% SLA`, `142 msgs queued`, `18 / 42 retrying`) instead of consuming `adminDeliveryStatsProvider`.
- **Status:** **C (Partially Implemented / Telemetry Mocked)**.
- **Action:** **FIX.** Wire `adminDeliveryStatsProvider` to fetch real database metrics (`total`, `delivered`, `failed`, `queued`, `deliveryRate`) and link tiles directly to filtered delivery logs.

### 2.2 Module 2: Integration Marketplace
- **Business Responsibility:** Configuration, credential vaulting, health checks, circuit breakers, and webhook replays for external service providers (Payment, Messaging, Maps, Storage, Telematics).
- **Route & Screen:** `/integrations` -> `IntegrationMarketplacePage` (`apps/admin_panel/lib/features/integrations/presentation/pages/integration_marketplace_page.dart`).
- **Backend Endpoints:**
  - `GET /api/v1/integrations/admin/providers`
  - `GET /api/v1/integrations/admin/providers/:category/:providerId`
  - `PUT /api/v1/integrations/admin/providers/:category/:providerId/config`
  - `POST /api/v1/integrations/admin/providers/:category/:providerId/toggle`
  - `POST /api/v1/integrations/admin/providers/:category/:providerId/test`
  - `GET /api/v1/integrations/admin/webhooks`
  - `POST /api/v1/integrations/admin/webhooks/:eventId/replay`
- **Database Models:** Prisma `IntegrationExecution`, `IntegrationAttempt`, `ProviderIncident`, `SystemConfig`.
- **Finding:** Fully functional backend integration control plane. The frontend was styled with consumer "Marketplace" / "App Store" terminology instead of an enterprise "Integrations Hub". The tab navigation had 8 competing internal tabs (`CATALOG`, `PACKS`, `PAYMENTS`, `COMMUNICATIONS`, `RULES`, `OPERATIONS`, `CONTROL_PLANE`, `COMPARISON`) where `/notification-rules` was simply tab 4.
- **Status:** **A (Implemented and Verified).**
- **Action:** **CONSOLIDATE.** Rename and focus the screen as **Integrations Hub**, cleanly exposing provider credentials (masked), circuit states, and webhook health without consumer marketplace noise.

### 2.3 Module 3: Event & Notification Rules
- **Business Responsibility:** Declarative event-to-channel routing policies (e.g., `BOOKING_CONFIRMED`, `PAYMENT_FAILED`, `DAMAGE_CLAIM_OPENED`), quiet hours compliance (TRAI 21:00-08:00 IST), priority tiering, and retry policies.
- **Route & Screen:** `/notification-rules` -> `NotificationRulesCentreWidget` embedded in `IntegrationMarketplacePage(initialTab: 'RULES')`.
- **Backend Endpoints:**
  - `GET /api/v1/integrations/admin/notification-rules`
  - `POST /api/v1/integrations/admin/notification-rules`
  - `PATCH /api/v1/integrations/admin/notification-rules/:id/toggle`
  - `POST /api/v1/integrations/admin/notification-rules/simulate`
- **Database Models:** Prisma `SystemConfig` (`key: 'communications.notification_rules'`).
- **Consumer Services:** `NotificationOrchestratorService.publishEvent()` automatically reads these rules to decide whether an event should dispatch, which channels are permitted, and whether quiet hours bypass applies.
- **Finding:** Complete persistence and evaluation verified in `admin_notification_rules_centre_test.dart` and `notifications-orchestrator.spec.ts`.
- **Status:** **A (Implemented and Verified).**
- **Action:** **KEEP.** Maintain explicit dedicated navigation under Messaging. Enforce RBAC permission checks on mutation endpoints.

### 2.4 Module 4: Message Templates
- **Business Responsibility:** Multi-language transactional and promotional template registry across WhatsApp, SMS, Email, and Push, supporting DLT registration IDs, variable validation, and live phone rendering.
- **Route & Screen:** `/templates` -> `CommunicationTemplatesPage` (`apps/admin_panel/lib/features/communications/presentation/pages/communication_templates_page.dart`).
- **Backend Endpoints:**
  - `POST /api/v1/integrations/admin/communication-ecosystem/templates/preview`
  - `GET /admin/whatsapp/templates`
- **Finding:** Rich interactive UI previewing English, Hindi, Telugu, Kannada, and Tamil with variable interpolation. However, the template list was defined entirely in frontend widget state (`_templates`) instead of being synchronized with canonical backend templates in `notification-templates.ts`.
- **Status:** **C (Partially Implemented / Static Template Catalog).**
- **Action:** **FIX.** Wire variable validation, enforce pre-send validation checks, and ensure consistency between frontend template definitions and backend canonical templates.

### 2.5 Module 5: Delivery Logs & Retries
- **Business Responsibility:** Centralized audit trail for all outbound messages across all channels, recording recipient, channel, delivery status (`DELIVERED`, `FAILED`, `DEAD_LETTER`, `QUEUED`), provider response, attempt count, and manual retry.
- **Route & Screen:** `/delivery-logs` -> `CommunicationDeliveryLogsPage` (`apps/admin_panel/lib/features/communications/presentation/pages/communication_delivery_logs_page.dart`).
- **Backend Endpoints:**
  - `GET /admin/notifications/deliveries`
  - `POST /admin/notifications/deliveries/:id/retry`
- **Database Models:** Prisma `NotificationDelivery`, `Notification`.
- **Finding:** Connected to real data via `AdminDeliveriesNotifier` and `adminNotificationsRepositoryProvider`. Deficiencies identified:
  1. Recipient phone numbers and email addresses were displayed in plaintext without PII masking.
  2. Manual retry lacked debounce protection to prevent accidental duplicate clicks.
- **Status:** **A (Implemented and Verified with Security Refinement Needed).**
- **Action:** **FIX.** Implement PII masking (`+91 98765*****`, `r***@domain.com`), debounce the retry button, and prevent retrying already-delivered messages.

### 2.6 Module 6: Push Notifications
- **Business Responsibility:** Mobile push announcement composer, target audience selection (All Users, Specific City, Single Phone), priority specification, and delivery history.
- **Route & Screen:** `/notifications` -> `PushNotificationsPage` (`apps/admin_panel/lib/features/notifications/presentation/pages/push_notifications_page.dart`).
- **Backend Endpoints:**
  - `POST /admin/notifications/send`
  - `GET /admin/notifications/history`
  - `GET /admin/notifications/stats`
  - `POST /admin/notifications/devices/cleanup`
- **Database Models:** Prisma `Notification`, `NotificationDelivery`, `UserDevice`.
- **Finding:** Working push dispatcher via Firebase Cloud Messaging (FCM). The delivery history table inside this page duplicates the unified `CommunicationDeliveryLogsPage`.
- **Status:** **A (Implemented and Verified).**
- **Action:** **CONSOLIDATE.** Retain `PushNotificationsPage` as a dedicated composer under Messaging, while pointing delivery trace links to the unified Delivery Logs. Gate send action with `campaign:manage` permission.

### 2.7 Module 7: WhatsApp Messaging
- **Business Responsibility:** Operational console for Meta Cloud WhatsApp API, tracking message logs, delivery receipts, template approval statuses, cost tracking in INR, and interactive compose/resend dialogs.
- **Route & Screen:** `/whatsapp` -> `AdminWhatsAppPage` (`apps/admin_panel/lib/features/whatsapp/presentation/pages/admin_whatsapp_page.dart`).
- **Backend Endpoints:**
  - `GET /admin/whatsapp/summary`
  - `GET /admin/whatsapp/messages`
  - `POST /admin/whatsapp/resend/:id`
  - `GET /admin/whatsapp/templates`
  - `POST /admin/whatsapp/send`
  - `GET /admin/whatsapp/messages/:id/timeline`
- **Database Models:** Prisma `CommunicationMessage`, `OtpChallenge`.
- **Finding:** Complete operational implementation verified in `admin_whatsapp_page_test.dart` and `whatsapp.spec.ts`. Supports 24-hour service window awareness, template parameter mapping, and timeline debugging.
- **Status:** **A (Implemented and Verified).**
- **Action:** **KEEP.** Retain as a dedicated channel console under Messaging.

### 2.8 Module 8: Workflow Automation
- **Business Responsibility:** Automated background sweeps, quote expiration, overdue rental tracking, pre-trip reminders, scheduled jobs, and declarative event workflows.
- **Route & Screen:** `/automation` -> `AdminAutomationOverviewPage` (`apps/admin_panel/lib/features/automation/presentation/pages/admin_automation_overview_page.dart`).
- **Backend Endpoints:**
  - `POST /rental/automation/run` (`RentalCoreController.runAutomation`)
  - `GET /api/v1/operations/workflows` (`OperationsController.getWorkflows`)
  - `GET /api/v1/operations/executions` (`OperationsController.getExecutions`)
  - `GET /api/v1/operations/rules` (`OperationsController.getRules`)
  - `GET /api/v1/operations/schedules` (`OperationsController.getSchedules`)
- **Backend Services:** `RentalAutomationService` (`car_rental_backend/src/bookings/rental-automation.service.ts`), `WorkflowEngineService`, `AutomationRuleEngineService`, `CleanupProcessor` (Bull queue).
- **Finding:** In `apps/admin_panel`, `AutomationCommandCentreWidget` displayed fake `_mockWorkflows` and `_mockExecutions`! It was completely disconnected from the actual backend automation services (`RentalAutomationService` and `OperationsController`). Real maintenance sweeps were executing invisibly without admin UI control.
- **Status:** **F (Mocked/Hardcoded in UI despite Backend Implementation).**
- **Action:** **FIX.** Connect `AdminAutomationOverviewPage` to real backend automation endpoints (`/rental/automation/run` and `api/v1/operations`), replace mock data with live execution results, and provide an interactive "Trigger Sweep" control for administrators.

---

## 3. Summary Status & Cleanup Matrix

| # | Module | Intended Responsibility | Current Screen | Backend Status | UI Status | Status | Recommended Action |
|---|---|---|---|---|---|:---:|---|
| 1 | **Communications Overview** | Observability & Buffer Telemetry | `CommunicationsOverviewPage` | Real API exists (`/admin/notifications/stats`) | Hardcoded fake numbers in KPI tiles | **C** | **FIX:** Bind `adminDeliveryStatsProvider` to display real DB counts. |
| 2 | **Integration Marketplace** | Provider Config & Gateway Control | `IntegrationMarketplacePage` | Full Enterprise Control Plane exists | Over-engineered "Marketplace" tabs | **A** | **CONSOLIDATE:** Rebrand as **Integrations Hub**, simplify tabs. |
| 3 | **Event & Notification Rules** | Declarative Policy & Channel Routing | `NotificationRulesCentreWidget` | Fully persisted in `SystemConfig` | Fully connected | **A** | **KEEP:** Retain under Messaging; enforce RBAC. |
| 4 | **Message Templates** | Multi-Language Template Studio | `CommunicationTemplatesPage` | Backend template engine exists | Local static array in widget | **C** | **FIX:** Enforce variable validation & canonical template sync. |
| 5 | **Delivery Logs & Retries** | Centralized Outbound Trace & Retries | `CommunicationDeliveryLogsPage` | Real DB models (`NotificationDelivery`) | Unmasked recipient PII | **A** | **FIX:** Add PII masking, debounced retry, status guard. |
| 6 | **Push Notifications** | Push Announcements & Audience Target | `PushNotificationsPage` | FCM Service + Device Registry | Duplicate delivery table | **A** | **CONSOLIDATE:** Retain composer; link to unified Delivery Logs. |
| 7 | **WhatsApp Messaging** | WhatsApp Business API Management | `AdminWhatsAppPage` | Real Meta API + Timeline | Fully connected | **A** | **KEEP:** Retain as dedicated channel console under Messaging. |
| 8 | **Workflow Automation** | Rental Sweeper & Event Workflows | `AdminAutomationOverviewPage` | Real `RentalAutomationService` + Ops API | Hardcoded mock workflows in UI | **F** | **FIX:** Connect to `RentalAutomationService` & `OperationsController`. |

