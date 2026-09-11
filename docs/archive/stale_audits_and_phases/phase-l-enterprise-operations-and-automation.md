# DRIVEGO — PHASE L: ENTERPRISE OPERATIONS, AUTOMATION & INTELLIGENCE CORE
## Technical Specification, Architecture & Operational Runbook

---

## 1. Executive Summary & Objective

DriveGo **Phase L** establishes the enterprise-grade Operations, Automation, and Intelligence backbone for the monorepo. Building directly on the foundational infrastructure from previous phases—such as the Provider Catalog, Provider Registry, Phase K Integration Runtime (with intelligent routing, circuit breakers, rate limiters, idempotency, and failure classification), Webhook Engine, and Multi-Level Configuration Engine—Phase L delivers a fully declarative, event-driven orchestration layer that powers all core car rental business processes without hardcoded procedural logic.

Key highlights of Phase L include:
- **Event-Driven Domain Foundation**: Standardized domain event envelopes with LRU/TTL deduplication, correlation ID propagation, and ring-buffer event persistence.
- **Enterprise Workflow Engine**: Finite-state machine supporting sequential steps, conditional branching, parallel execution, delays, safe retries, dead-letter capture, and automated compensation rollbacks.
- **Automation Rule Engine**: Generic predicate tree evaluation (`EQUALS`, `CONTAINS`, `GREATER_THAN`, `DATE_COMPARISON`, etc.) with `AND`/`OR`/`NOT` logic and multi-action dispatching.
- **Scheduling Engine**: Timezone-aware job scheduler supporting one-time, recurring, and cron-style schedules integrated with domain event dispatching.
- **Enterprise Notification Orchestration**: Multi-channel fallback chains (`WhatsApp` $\to$ `SMS` $\to$ `Push` $\to$ `Email`) and provider fallback routing executed via `IntegrationRuntimeService`.
- **Customer Communication Intelligence**: Preference learning, failure penalty decay, exponential smoothing score boosts, and quiet-hours evaluation.
- **Human-in-the-Loop (HITL) Approval Subsystem**: Multi-tier approval workflows for vendor onboarding, large refunds, damage claims, and manual overrides.
- **Unified Correlation Timeline Tracer**: End-to-end operational visibility correlating customer actions, bookings, payments, integrations, webhooks, events, and workflows with automated secret sanitization.
- **Admin Automation Command Centre**: Responsive Flutter UI featuring KPI dashboards, visual workflow pipelines, execution history with one-click retry, rule toggles, and interactive approval cards.

---

## 2. Event-Driven Domain Foundation

### 2.1 Standardized Domain Event Envelope
Every business module (Bookings, Payments, Fleet, KYC, Auth, Compliance) publishes events wrapped in a standardized envelope:

```typescript
export interface DomainEvent<T = any> {
  eventId: string;          // Globally unique ID (e.g. evt_1725881023_a9b1c2)
  eventType: string;        // E.g. BOOKING_CREATED, PAYMENT_FAILED, VEHICLE_OVERDUE
  aggregateType: string;    // E.g. 'BOOKING' | 'PAYMENT' | 'VEHICLE' | 'SYSTEM'
  aggregateId: string;      // ID of target entity
  tenantContext?: {
    tenantId?: string;
    vendorId?: string;
    branchId?: string;
  };
  actor?: {
    id: string;
    role: string;
    type?: string;
  };
  timestamp: string;        // ISO 8601 UTC
  correlationId: string;    // Propagated distributed trace ID
  causationId?: string;     // Parent event ID triggering this event
  version: number;          // Schema version
  payload: T;               // Domain-specific data
}
```

### 2.2 Deduplication & Concurrency Protection
The `DomainEventBusService` tracks processed `eventId` values within an in-memory cache with an automated 1-hour TTL expiration. Any duplicate event received with an existing ID is dropped with a structured log warning (`[DUPLICATE_EVENT_DROPPED]`), preventing duplicate billing charges, redundant SMS dispatches, or out-of-order state corruptions.

---

## 3. Enterprise Workflow Engine

### 3.1 Architecture & Node Model
Workflows are defined declaratively as directed graphs consisting of strongly typed steps:

```
[TRIGGER] 
   └──> [NOTIFICATION] 
           └──> [CONDITION / BRANCH] 
                   ├── True  ──> [ACTION] ──> [END]
                   └── False ──> [DELAY / NOTIFICATION] ──> [END]
```

Step types supported:
1. `TRIGGER`: Defines event triggering the workflow.
2. `CONDITION` / `BRANCH`: Evaluates expressions against `contextData` and selects `trueStepId` vs `falseStepId`.
3. `ACTION`: In-memory context mutation or state transitions.
4. `NOTIFICATION`: Multi-channel communication routed through `IntegrationRuntimeService`.
5. `PROVIDER_CALL`: Direct invocation of external integrations (Payments, Maps, KYC, Telematics).
6. `DELAY`: Bounded async delay.
7. `PARALLEL`: Fan-out execution of concurrent sub-actions.
8. `APPROVAL`: Human-in-the-loop gate pausing execution until approved.
9. `END`: Final successful terminal state.

### 3.2 Pre-Configured Seeded Workflows
1. **`WF_BOOKING_LIFECYCLE`**:
   - Trigger: `BOOKING_CREATED`
   - Dispatches WhatsApp confirmation to customer.
   - Evaluates `paymentStatus`.
   - If `SUCCESS`: Assigns vehicle and schedules pickup checklist.
   - If `PENDING`: Sends SMS payment reminder with checkout link.
2. **`WF_PAYMENT_FAILURE_RECOVERY`**:
   - Trigger: `PAYMENT_FAILED`
   - Sends instant WhatsApp recovery message with retry token.
   - Creates support task for customer recovery team.
3. **`WF_VEHICLE_OVERDUE`**:
   - Trigger: `VEHICLE_OVERDUE`
   - Dispatches urgent return SMS notice.
   - Pings IoT GPS telematics to acquire live coordinates.
4. **`WF_COMPLIANCE_EXPIRY`**:
   - Trigger: `DOCUMENT_EXPIRING`
   - Alerts vendor 30 days prior to insurance/permit expiration.
   - Creates compliance renewal ticket.

### 3.3 Failure Classification & Compensation Rollback
When a step encounters an unhandled error:
- If `onFailure` step is configured, execution branches to the fallback step.
- If `compensationStepId` is defined, the engine executes the compensating rollback action to ensure data consistency.
- If unrecoverable, execution moves to `FAILED` status, logging root cause, error classification, and failed step ID into dead-letter storage.
- Administrators can invoke `POST /api/v1/operations/executions/:id/retry` with optional parameter overrides to resume failed executions from any step.

---

## 4. Automation Rule Engine

The `AutomationRuleEngineService` evaluates active rules against all domain events globally in order of priority:

```
IF   payload.amount > 0 AND payload.bookingStatus == 'CONFIRMED'
THEN SEND_NOTIFICATION (WhatsApp -> SMS Fallback)
```

Operators supported:
- `EQUALS`, `NOT_EQUALS`
- `GREATER_THAN`, `LESS_THAN`
- `CONTAINS`, `IN`, `EXISTS`
- `DATE_COMPARISON`, `RELATIVE_DATE` (e.g. `+24h`, `-7d`)
- Logical composition: `AND`, `OR`, `NOT`
- Recursive nested predicate trees

Multi-Tenant Scoping:
Rules can be scoped at `PLATFORM`, `VENDOR`, or `BRANCH` level. A rule scoped to a specific vendor only triggers when incoming event `tenantContext.vendorId` matches, preventing cross-tenant leakage.

---

## 5. Scheduling Engine

The `SchedulingEngineService` provides background task execution:
- **`ONE_TIME`**: Scheduled for a specific future ISO 8601 timestamp.
- **`RECURRING`**: Reschedules automatically after each execution interval.
- **`CRON`**: Evaluates cron expressions with timezone support (`Asia/Kolkata` default).

Execution guarantees:
- Status lifecycle: `SCHEDULED` $\to$ `RUNNING` $\to$ `COMPLETED` / `FAILED` / `CANCELLED`.
- Exponential backoff retries upon transient errors up to `maxRetries`.
- Dispatches scheduled domain events (`SCHEDULED_<actionType>`) so workflows and notification systems can trigger reactively.
- Interactive controls: `POST /api/v1/operations/schedules/:id/run` triggers an immediate run for testing or maintenance.

---

## 6. Enterprise Notification Orchestration & Communication Intelligence

### 6.1 Channel Hierarchy & Fallback
```
Primary Preferred Channel (e.g., WhatsApp)
       │ (on failure / 429 / offline)
       ▼
Secondary Fallback (e.g., SMS)
       │ (on failure)
       ▼
Tertiary Fallback (Push Notification)
       │ (on failure)
       ▼
Transactional Email
```

### 6.2 Communication Intelligence & Learning
The `CommunicationIntelligenceService` maintains a per-user communication profile:
- Tracks `preferredChannel`, `preferredLanguage`, and `optedOutChannels`.
- Tracks real-time `channelSuccessRates` (0.0 to 1.0) and failure counts.
- **Feedback Learning**:
  - Success: Applies exponential smoothing score boost: $S_{new} = \min(1.0, S_{old} \times 0.9 + 0.1)$.
  - Failure: Applies decay penalty: $S_{new} = \max(0.1, S_{old} \times 0.8)$.
- **Quiet Hours Guard**: Automatically checks whether current local time falls outside acceptable delivery windows (e.g., 9 PM to 9 AM) before dispatching non-critical marketing messages.
- **AI/ML Extension Hook**: `predictOptimalSendTime(userId)` provides an interface returning `recommendedDelayMinutes` and `confidenceScore`.

---

## 7. Human-in-the-Loop (HITL) Approval Subsystem

Manages high-value and sensitive operational decisions:
- Supported categories: `VENDOR_ONBOARDING`, `LARGE_REFUND`, `DAMAGE_CLAIM_PAYOUT`, `VEHICLE_RETIREMENT`, `MANUAL_OVERRIDE`.
- Step progression: Step $i$ must be explicitly approved by an authorized role before Step $i+1$ becomes active.
- When all steps are approved, `overallStatus` transitions to `APPROVED`.
- If any step is rejected, `overallStatus` immediately transitions to `REJECTED`, notifying the requestor and halting the associated workflow.

---

## 8. Cross-Domain Correlation Audit & Secret Masking

The `OperationsAuditTracerService` maintains a unified chronological timeline accessible by `correlationId`.

### 8.1 Automated Redaction
All payload attributes containing sensitive credentials or customer privacy data are recursively sanitized:
- Redacted keys: `password`, `token`, `secret`, `apikey`, `key`, `authorization`, `cardnumber`, `cvv`, `access_token`.
- Redacted value replacement: `***REDACTED***`.

### 8.2 Unified Journey Timeline
An administrator inspecting correlation ID `cor_bk_delhi_9921` sees:
1. `CUSTOMER`: Booking initiated
2. `PAYMENTS`: Payment captured via Razorpay
3. `INTEGRATIONS`: Webhook received and signature verified
4. `WORKFLOW`: Event `PAYMENT_SUCCESS` processed by `WF_BOOKING_LIFECYCLE`
5. `NOTIFICATIONS`: WhatsApp confirmation sent via Meta Cloud API
6. `FLEET`: Vehicle assigned and reserved from Hub

---

## 9. Flutter Admin Automation Command Centre

Located in `apps/admin_panel/lib/features/automation`:
- **Command Centre**: Executive KPI summary cards, quick execution health metrics, pending approval alerts.
- **Workflow Definitions**: Interactive cards displaying pipeline step nodes (`TRIGGER`, `NOTIFICATION`, `CONDITION`, `ACTION`, `END`) with test run buttons.
- **Executions & Retries**: Filterable execution grid with one-click **Retry Execution** for failed items.
- **Automation Rules**: Predicate tree inspector with inline toggle switches.
- **Approvals & HITL**: Approval request cards with single-click `Approve Step` and `Reject` actions.
- **Scheduled Jobs**: List of background cron/recurring jobs with `Run Now` and `Cancel` triggers.
- **Correlation Timeline**: Step-by-step visual trace diagram tracking operational lifecycles.

---

## 10. REST API Specification

| Endpoint | Method | Description |
|---|---|---|
| `/api/v1/operations/workflows` | GET | List workflow definitions (filter by status, triggerEvent) |
| `/api/v1/operations/workflows/:id` | GET | Get single workflow definition |
| `/api/v1/operations/workflows` | POST | Register or update workflow definition |
| `/api/v1/operations/workflows/:id/trigger` | POST | Manually trigger workflow execution |
| `/api/v1/operations/executions` | GET | Query workflow execution history |
| `/api/v1/operations/executions/:id` | GET | Get execution details and step breakdown |
| `/api/v1/operations/executions/:id/retry` | POST | Retry a failed execution |
| `/api/v1/operations/rules` | GET | List automation rules |
| `/api/v1/operations/rules` | POST | Create automation rule |
| `/api/v1/operations/rules/:id` | PUT | Update automation rule |
| `/api/v1/operations/rules/:id` | DELETE | Remove automation rule |
| `/api/v1/operations/approvals` | GET | List pending/completed approval requests |
| `/api/v1/operations/approvals` | POST | Create approval request |
| `/api/v1/operations/approvals/:id/decide` | POST | Record step approval or rejection decision |
| `/api/v1/operations/schedules` | GET | List scheduled jobs |
| `/api/v1/operations/schedules` | POST | Create scheduled job |
| `/api/v1/operations/schedules/:id` | DELETE | Cancel scheduled job |
| `/api/v1/operations/schedules/:id/run` | POST | Trigger immediate execution of scheduled job |
| `/api/v1/operations/events` | GET | Query recent domain events |
| `/api/v1/operations/events/publish` | POST | Publish domain event |
| `/api/v1/operations/audit/timeline/:correlationId` | GET | Fetch cross-domain correlation timeline |
| `/api/v1/operations/audit/activities` | GET | Query recent audit activities |
| `/api/v1/operations/communication/preferences/:userId` | GET | Get customer communication profile |
| `/api/v1/operations/communication/preferences/:userId` | PUT | Update customer communication preferences |
| `/api/v1/operations/communication/predict-timing/:userId` | GET | Predict optimal send timing |

---

## 11. Automated Test Verification Results

All automated test suites pass with zero failures and zero regressions:

1. **Phase L Operations & Automation Suite**:
   - `src/operations/tests/phase-l-enterprise-operations-automation.spec.ts`: **17 / 17 passed (100%)**
2. **Integration Runtime & Providers Suite**:
   - `src/integrations/tests/*.spec.ts`: **233 / 233 passed (100%)**
3. **Fleet Intelligence Suite**:
   - `src/fleet/tests/phase-m-enterprise-fleet-intelligence.spec.ts`: **20 / 20 passed (100%)**
4. **Backend TypeScript Build**:
   - `npm run build`: **Clean compilation (code 0)**
5. **Database Client Generation**:
   - `npx prisma generate`: **Clean generation (code 0)**
6. **Flutter Admin Panel Analyzer**:
   - `flutter analyze`: **No issues found (code 0)**
7. **Flutter Admin Panel Test Suite**:
   - `flutter test`: **57 / 57 passed (100%)**
