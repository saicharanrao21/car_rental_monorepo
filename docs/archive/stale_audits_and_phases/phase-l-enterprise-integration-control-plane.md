# DRIVEGO — PHASE L: ENTERPRISE INTEGRATION CONTROL PLANE, PROVIDER INTELLIGENCE & GOVERNANCE

## 1. Executive Summary & Architectural Overview

Phase L elevates the DriveGo Integration Runtime created in Phase K into an **Enterprise Integration Control Plane**. The platform now supports a large, open provider ecosystem capable of housing hundreds of interchangeable providers across India, regional, and global markets.

```
       +-------------------------------------------------------------------------------+
       |                      DRIVEGO API & BUSINESS MODULES                            |
       |  (Bookings, Fleet Availability, Financial Reconciliation, Auth, Notifications)|
       +---------------------------------------+---------------------------------------+
                                               | Requests CAPABILITY (e.g. UPI, PAN_VERIFY)
                                               v
       +-------------------------------------------------------------------------------+
       |                      ENTERPRISE INTEGRATION CONTROL PLANE                     |
       +-------------------------------------------------------------------------------+
       |  [Provider Directory & Taxonomies]  <--->  [Capability Matrix & Match Engine] |
       |  [Deterministic Scoring Engine]     <--->  [SCORE_OPTIMIZED Dynamic Router]   |
       |  [Automated Incident Desk]          <--->  [Governance Change Audit Ledger]   |
       |  [Proactive Recommendation Engine]  <--->  [Simulation & Resilience Lab]      |
       +---------------------------------------+---------------------------------------+
                                               | Isolated Credentials & Sandboxing
                                               v
       +-------------------------------------------------------------------------------+
       |                         INTERCHANGEABLE PROVIDER PACKS                        |
       |  Payments: Razorpay, Cashfree, Stripe, PayU, PhonePe, Adyen                   |
       |  Messaging: Meta WhatsApp, Gupshup, Twilio, Msg91, Resend, OneSignal, FCM     |
       |  Identity/Trust: Surepass, HyperVerge (PAN, Aadhaar, DL, RC, OCR, Liveness)   |
       |  Maps/Geo: Google Maps, Mapbox (Geocoding, Routes, Distance Matrix, Places)    |
       |  Telematics: Traccar, Teltonika, IoT OBD, GPS Gate                            |
       |  Finance: Zoho Books, Tally Prime, Stripe Invoicing                           |
       |  Intelligence: Google Gemini AI, Meilisearch, PostHog Analytics               |
       +-------------------------------------------------------------------------------+
```

---

## 2. Enterprise Provider Directory & Lifecycle

Providers are decoupled from business service code through `ProviderDirectoryService` and `ProviderOnboardingService`.

### 2.1 Provider Metadata Schema
Each directory entry encapsulates complete operational and commercial metadata:
- **Identity & Legal**: `providerId`, `displayName`, `legalEntityName`, `category`, `subcategories`, `websiteUrl`, `documentationUrl`.
- **Geographic & Currency Scope**: `supportedCountries` (ISO codes or `GLOBAL`), `supportedCurrencies` (ISO 4217), `supportedLanguages`.
- **Capability Manifest**: Normalized capability tokens mapped to adapter contracts.
- **Environments**: Isolated support for `DEVELOPMENT`, `STAGING`, `SANDBOX`, and `LIVE`.
- **SLA Commitments**: Uptime guarantee (e.g., 99.95%), response time commitment (P50/P95), support tier (`COMMUNITY`, `STANDARD_8X5`, `PRIORITY_24X7`, `MISSION_CRITICAL`).
- **Commercial Model**: Fixed transaction fees, percentage cuts, setup fees, monthly minimums, and volume discounts (`ProviderPricingType`).
- **Certification State**: `COMMUNITY` $\to$ `CATALOG` $\to$ `CONTRACT_VALIDATED` $\to$ `SANDBOX_VALIDATED` $\to$ `FAILOVER_VALIDATED` $\to$ `PRODUCTION_READY` $\to$ `ENTERPRISE_CERTIFIED`.

### 2.2 Onboarding Pipeline
A 7-step validation pipeline enforces operational compliance before activating any provider:
1. **Metadata Specification**: Unique lowercase identifier, legal name, category verification.
2. **Credential Schema Declaration**: Strict typing for required secrets and API tokens.
3. **Capability Matrix Conformance**: Declaration of normalized capability tokens.
4. **SLA & Rate Limits Guarantee**: Minimum 90% SLA commitment and explicit RPS ceilings.
5. **Regional Scope**: Country code ISO compliance and multi-currency declarations.
6. **Fallback Compatibility Definition**: Declaration of pre-approved fallback adapters.
7. **Commercial Pricing Model**: Explicit transaction percentage and fixed fee declarations.

---

## 3. Extensible Provider Taxonomy

The taxonomy spans 50+ enterprise service categories covering the entire vehicle rental lifecycle:

| Domain | Categories | Capabilities |
| :--- | :--- | :--- |
| **Payments** | `PAYMENT`, `PAYOUTS`, `OPEN_BANKING` | UPI, Cards, Netbanking, Wallets, Escrow, Recurring Mandates, Instant Refunds |
| **Messaging** | `MESSAGING_WHATSAPP`, `MESSAGING_SMS`, `MESSAGING_EMAIL`, `MESSAGING_PUSH`, `VOICE_IVR` | Template WhatsApp, DND SMS, Rich Push, IVR Callout, Transactional Receipts |
| **Trust & KYC** | `IDENTITY_VERIFICATION`, `DOCUMENT_VERIFICATION`, `OCR`, `FACE_LIVENESS` | PAN, Aadhaar OKYC, Driving Licence, Vehicle RC, GSTIN, Face Liveness, Document OCR |
| **Maps & Geo** | `MAPS`, `ROUTING_DISTANCE`, `PLACES_POI` | Geocoding, Reverse Geocoding, Turn-by-turn Routing, Distance Matrix, Geofences |
| **Telematics** | `VEHICLE_TRACKING`, `FLEET_IOT` | GPS Telemetry, Remote Immobilization, Fuel Sensing, Odometer Polling, Diagnostics |
| **Finance** | `ACCOUNTING`, `ERP`, `TAX_GST`, `INVOICING` | Automated Invoicing, GST E-way Bills, Double-Entry Ledger, Payout Reconciliation |
| **Intelligence** | `AI`, `SEARCH`, `ANALYTICS` | Gemini LLM Chat, Meilisearch Full-Text Discovery, PostHog Product Telemetry |

---

## 4. Normalized Capability Matrix

Business logic queries capabilities rather than concrete providers:

```typescript
// Business layer requests capability
const chain = await routingService.resolveRoutingChain({
  category: IntegrationCategory.PAYMENT,
  capability: 'PAYMENT_CREATE_ORDER',
  currency: 'INR',
  region: 'IN',
  routingStrategy: RoutingStrategy.SCORE_OPTIMIZED,
});
```

The `CapabilityMatrixService` handles normalization, canonical mappings, and fuzzy matching (e.g. mapping `CREATE_ORDER` $\to$ `PAYMENT_CREATE_ORDER` across Razorpay, Cashfree, and PayU).

---

## 5. Multi-Factor Deterministic Scoring Engine

The `ProviderScoringService` evaluates providers dynamically on a 0–100 scale using deterministic mathematical weights:

$$\text{Final Score} = \sum (W_i \times F_i) - \text{Penalties}$$

### 5.1 Scoring Factors
- **Health Factor (25%)**: Real-time heartbeat and availability probe (Healthy = 100, Degraded = 50, Down = 0).
- **Historical Reliability (20%)**: Long-term rolling execution success rate.
- **Latency Factor (15%)**: P50 latency relative to category tolerance threshold (e.g., $<250\text{ms}$).
- **Capability Match Factor (15%)**: Coverage percentage of required and preferred capabilities.
- **Regional & Currency Suitability (10%)**: Direct domestic routing match (e.g. INR + IN).
- **Cost Efficiency Factor (5%)**: Percentage processing fees and flat rates.
- **Configured Business Priority (10%)**: Operator-defined strategic weight.

### 5.2 Dynamic Penalties
- **Circuit Breaker Open**: $-60$ points (immediately moves candidate to fallback chain tail).
- **Circuit Breaker Half-Open**: $-25$ points (limits candidate exposure).
- **Degraded Status**: $-20$ points; **Unavailable**: $-50$ points.
- **Rate-Limit Pressure**: Up to $-30$ points based on active 429 streaks.

---

## 6. Intelligent Routing & Failover Architecture

The `ProviderRoutingService` introduces the `SCORE_OPTIMIZED` strategy alongside existing strategies (`PRIORITY`, `ROUND_ROBIN`, `WEIGHTED`, `LEAST_LATENCY`, `HEALTH_BASED`, `COST_OPTIMIZED`):

1. Discover all candidate providers in the category.
2. Filter candidates by capability conformance, regional eligibility, and environment isolation.
3. Compute multi-factor deterministic score for every candidate.
4. Elevate highest-scoring candidate to **Primary**.
5. Construct **Fallback Chain** in descending score order.
6. Quarantine providers with open circuit breakers to the tail of the fallback chain.
7. Preserve Phase K financial idempotency safety guards (non-idempotent operations abort rather than failover unsafely).

---

## 7. Incident Management & Operations Desk

The `ProviderIncidentService` manages the full enterprise incident lifecycle:

$$\text{DETECTED} \longrightarrow \text{INVESTIGATING} \longrightarrow \text{IDENTIFIED} \longrightarrow \text{MONITORING} \longrightarrow \text{RESOLVED}$$

- **Auto-Detection**: Breached circuit breakers or health probes automatically generate incident records.
- **Deduplication & Escalation**: Successive failures on active incidents increment `failureCount` and update severity rather than spamming duplicate records.
- **Operator Governance**: Explicit API endpoints for acknowledging incidents (`actorId` tracked) and resolving with mandatory post-mortem resolution notes.
- **Persistence**: Hybrid in-memory high-throughput cache backed by Prisma `ProviderIncident` records.

---

## 8. Provider Change Audit & Secret Redaction

Every administrative change is audited by `ProviderChangeAuditService` and persisted to `ProviderChangeEvent`:

- **Audited Change Types**: `CREDENTIAL_UPDATE`, `ACTIVATION_STATE_CHANGE`, `PRIORITY_UPDATE`, `ROUTING_POLICY_CHANGE`, `FALLBACK_CHAIN_CHANGE`, `ENVIRONMENT_CHANGE`, `WEBHOOK_CONFIG_CHANGE`, `ONBOARDING_COMPLETED`.
- **Recursive Secret Redaction**: All payloads pass through a recursive sanitizer. Any key containing `secret`, `password`, `token`, `apikey`, `privatekey`, `auth`, `signature`, or `webhooksecret` is strictly replaced with `***REDACTED***`.
- **State Diffing**: Captures sanitized `beforeSnapshot` and `afterSnapshot` with actor credentials and administrative rationale.

---

## 9. Proactive Recommendations with Human Approval Boundaries

The `ProviderRecommendationService` scans telemetry to surface actionable optimizations:
- **Single Point of Failure (SPOF)**: Alerts when a critical category relies on a single provider without fallback redundancy.
- **Sustained Degradation Reroute**: Proposes shifting traffic when a provider trips its circuit or maintains high latency.
- **Cost Optimization**: Identifies domestic volume processed by high-fee gateways (e.g. Stripe at 2.9% vs Cashfree at 1.9%) and computes monthly cost savings estimates.
- **Human Approval Boundary**: Recommendations are advisory; changes require operator approval (`approveRecommendation` / `dismissRecommendation`).

---

## 10. Simulation Test Lab

The `ProviderSimulationService` provides a safe sandbox test lab covering 11 realistic failure scenarios:
1. `SUCCESS`: Valid dummy payload with generated reference IDs.
2. `TIMEOUT`: Injected delays triggering timeout policies.
3. `NETWORK_ERROR`: Unreachable upstream simulation.
4. `AUTH_401`: Expired token / invalid API key simulation.
5. `FORBIDDEN_403`: Capability permission failure simulation.
6. `RATE_LIMIT_429`: Upstream quota exhaustion with `retry-after` headers.
7. `PROVIDER_DECLINE`: Business card decline or balance shortfall.
8. `MALFORMED_RESPONSE`: Invalid JSON payload parsing test.
9. `WEBHOOK_SIGNATURE_MISMATCH`: Signature mismatch verification test.
10. `LATENCY_INJECTION`: Programmable latency delay test.
11. `PARTIAL_FAILURE`: Primary operation success with asynchronous notification failure.

---

## 11. Flutter Admin Control Plane UI

Integrated into `apps/admin_panel` under the `IntegrationMarketplacePage` with a dedicated **Control Plane & Intelligence** tab (`IntegrationControlPlaneWidget`):

- **Executive KPI Strip**: Real-time cards for Total Providers, Active Providers, Dynamic Routing Strategy, Open Incidents, and Active Recommendations.
- **Sub-Tab 1 — Enterprise Directory**: Searchable, filterable by category and country, capability badges, SLA, latency P50, and certification tier tags.
- **Sub-Tab 2 — Multi-Factor Scoring Explorer**: Visual breakdown of health, reliability, latency, cost index, and circuit breaker status with deterministic progress bars.
- **Sub-Tab 3 — Incident Desk**: Operational incident list with severity badges, detection source tags, acknowledge action, and resolve modal with resolution notes.
- **Sub-Tab 4 — AI & Proactive Recommendations**: Impact-quantified recommendations (e.g. ₹45,000/mo fee savings) with interactive Approve and Dismiss actions.
- **Sub-Tab 5 — Governance & Change Audit**: Chronological ledger of configuration changes, before/after diffs, actor attribution, and sanitized secrets.
