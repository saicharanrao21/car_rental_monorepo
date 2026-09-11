# DriveGo — Phase 27.5 Architecture & Operations Report
## Communication, Notification & Customer Support Operations Foundation

### A. Starting SHA
- `5354763aa3528dc2c8abfedb804a31aa89f18558`

---

### B. Implementation & Scope Classification Matrix

| Component | Status | Details |
| :--- | :--- | :--- |
| **Notification Deduplication** | `IMPLEMENTED` & `VERIFIED` | Database uniqueness via `idempotencyKey` prevents duplicate notifications across retries, worker restarts, and concurrent requests. |
| **Multi-Device Token Sessions** | `IMPLEMENTED` & `VERIFIED` | `UserDevice` model tracks multiple active device tokens per user (`ANDROID`, `IOS`, `WEB`) with automatic multicast delivery and logout unregistration. |
| **Notification Preferences** | `IMPLEMENTED` & `VERIFIED` | Granular per-user toggles for promotional and operational channels. Mandatory transactional events strictly bypass promotional opt-outs. |
| **Customer & Vendor In-App Center** | `IMPLEMENTED` & `VERIFIED` | Fast unread counting, paginated history, category filtering, and atomic read-marking endpoints. |
| **Async Multi-Channel Delivery** | `IMPLEMENTED` & `VERIFIED` | In-app notification acts as synchronous source of truth; external SMS and Email are dispatched asynchronously via BullMQ. |
| **Support Ticket SLA Engine** | `IMPLEMENTED` & `VERIFIED` | Configurable response/resolution targets via `SystemConfig` (`support.sla`), automated deadline calculation on creation, and max open ticket bounds. |
| **Ticket Escalation & Internal Notes**| `IMPLEMENTED` & `VERIFIED` | Tiered escalation tracking with audit logging. Internal notes (`isInternal: true`) are strictly filtered from customer and vendor access. |
| **Dispute & Evidence Management** | `IMPLEMENTED` & `VERIFIED` | Booking-linked dispute workflow with strict raiser/vendor authorization and evidence attachments. |
| **Full Call-Center / CRM Suite** | `DEFERRED` | Full telephony integration, agent live-call routing, and third-party CRM sync are deferred to avoid premature overengineering. |
| **Real WhatsApp Delivery Integration** | `FOUNDATION ONLY` | Data contracts, message status tracking, and templates established; real WhatsApp provider delivery requires live Meta Cloud API credentials. |

---

### C. Notification Architecture & Event Deduplication
- **Authoritative Source of Truth**: The database `Notification` record is created synchronously within business workflows.
- **Idempotency Guarantee**: Every notification supports an `idempotencyKey` (e.g. `notif_tkt_created_123`, `evt_booking_confirmed_456`). If a duplicate key is presented, the existing record is returned without re-dispatching external push/SMS/email.
- **Multi-Device Support**: Users can have multiple concurrent active devices in `UserDevice`. `FcmService` automatically switches between single `sendToUser` and multicast `sendMulticast` based on active device count.

---

### D. Notification Preferences & Channel Governance
- **Mandatory Transactional Invariant**: Critical operational events (`BOOKING_CONFIRMED`, `PAYMENT_SUCCESS`, `REFUND_COMPLETED`, `SECURITY_ALERT`, `OTP`) cannot be silenced by promotional opt-outs.
- **Granular Toggles**: Configurable via `NotificationPreference` for `promotionalPush`, `promotionalSms`, `promotionalEmail`, `promotionalWhatsApp`, etc.

---

### E. Support Ticket SLA & Escalation
- **Dynamic SLA Targets**:
  - `URGENT`: 15 min first response, 120 min resolution.
  - `HIGH`: 60 min first response, 480 min resolution.
  - `NORMAL`: 240 min first response, 1440 min resolution.
- **First Response Tracking**: `firstRespondedAt` is recorded automatically on the first agent reply.
- **Multi-Tier Escalation**: `escalateTicket` increments `escalationTier`, elevates priority to `URGENT`, logs an internal note, and creates an immutable `AuditLog` entry.
- **Customer & Vendor Isolation**: All endpoints verify ownership (`customerId` or booking `vendorId`). Internal notes (`isInternal: true`) are strictly stripped before returning data to customers or vendors.

---

### F. Financial Safety
- Support agents cannot casually mutate financial state (wallet balances, payment status, refunds). All financial mutations require dedicated finance workflows with pessimistic locking and double-entry ledger records.

---

### G. Database & Index Strategy
- `Notification`: Indexed on `[userId]`, `[isRead]`, `[userId, isRead, createdAt]`, `[userId, category]`, `[createdAt]`, with unique `idempotencyKey`.
- `UserDevice`: Indexed on `[userId, isActive]`, `[token]`, `[lastSeenAt]`.
- `SupportTicket`: Indexed on `[customerId]`, `[bookingId]`, `[status]`, `[category]`, `[priority]`, `[assignedToUserId]`, `[customerId, status]`.

---

### H. Verification Summary
- **Backend Tests**: 72/72 suites passed, 535/535 tests passed (100%).
- **NestJS Compilation**: Clean build with 0 TypeScript errors.
- **Flutter Analyze**: 0 issues found across all 5 workspace modules.
- **Flutter Tests**:
  - Customer App: 88/88 passed
  - Vendor App: 17/17 passed
  - Admin Panel: 11/11 passed
  - Total Flutter: 116/116 passed.

---

### I. Deferred Work
- Full call-center / CRM suite integration.
- Live Meta Cloud API WhatsApp provider credentials.
