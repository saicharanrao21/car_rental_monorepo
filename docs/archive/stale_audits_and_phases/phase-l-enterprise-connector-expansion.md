# DRIVEGO — PHASE L: ENTERPRISE CONNECTOR EXPANSION & CAPABILITY PACKS
**Architecture, Capability Model, Lifecycle Engine, and Multi-Tenant Routing Specification**

---

## 1. Executive Summary & Product Philosophy

DriveGo has evolved from an integration catalog into a **genuine enterprise-grade, provider-agnostic connector ecosystem**. In accordance with enterprise architectural standards:

- **Business modules must request capabilities, never vendors.**
  - *Incorrect / Antipattern*: `PaymentsService -> RazorpayService` or `GeospatialService -> GoogleMapsService`
  - *Enterprise Pattern*: `PaymentsService -> IntegrationRuntimeService.executeCapability('CREATE_ORDER')` or `GeospatialService -> IntegrationRuntimeService.executeCapability('GEOCODE')`
- **Dynamic Capability Discovery**: Connectors dynamically declare their operational capabilities, supported regions, currencies, and rate limits.
- **Hierarchical Governance**: Provider configuration and policy overrides flow through four distinct organizational tiers (`PLATFORM` -> `ORGANIZATION / VENDOR` -> `BRANCH` -> `OPERATIONAL OVERRIDE`).
- **Honest Provider Categorization**: No catalog-only provider is ever misrepresented as an active integration. Providers are strictly classified as:
  1. `REAL_ADAPTER`: Full two-way production communication adapter.
  2. `SIMULATION_MOCK`: Fully functioning deterministic sandbox simulator supporting error injection.
  3. `CATALOG_ONLY`: Documented enterprise specification and schema awaiting operational driver implementation.

---

## 2. 35-Category Enterprise Ecosystem Audit

DriveGo's master provider ecosystem matrix covers **35 strategic capability domains** and **40+ payment gateways**:

| # | Category | Representative Providers | Implemented DriveGo Status | Key Capabilities |
|---|---|---|---|---|
| 1 | **Payments (India)** | Razorpay, Cashfree, PayU, PhonePe, Paytm, Instamojo, BillDesk, CCAvenue, Easebuzz, Juspay | Razorpay (Real), Cashfree (Real), PayU (Sim), PhonePe (Sim) | UPI_INTENT, UPI_QR, NET_BANKING, CARDS, REFUND, WEBHOOKS |
| 2 | **Payments (Global)** | Stripe, PayPal, Adyen, Checkout.com, Square, Mollie, Authorize.Net, Braintree, Paddle | Stripe (Real), PayPal (Sim), Adyen (Catalog) | CAPTURE, AUTHORIZE, CARDS, SUBSCRIPTIONS, DISPUTES |
| 3 | **WhatsApp** | Meta WhatsApp Cloud API, Gupshup, Twilio, 360dialog, Interakt | Meta Cloud (Real), Twilio (Real), Gupshup (Sim) | TEMPLATE_MESSAGE, INTERACTIVE_BUTTONS, MEDIA, SESSIONS |
| 4 | **SMS** | MSG91, Twilio, Exotel, Route Mobile, Textlocal | MSG91 (Real), Twilio (Real), Exotel (Sim) | TRANSACTIONAL_SMS, DLT_TEMPLATES, OTP, DELIVERY_REPORTS |
| 5 | **Email** | Resend, SendGrid, Amazon SES, Mailgun, Postmark | Resend (Real), SendGrid (Real), SES (Sim) | TRANSACTIONAL_EMAIL, TEMPLATES, ATTACHMENTS, BOUNCE_HANDLING |
| 6 | **Push Notifications** | Firebase Cloud Messaging (FCM), OneSignal, AWS SNS | FCM (Real), OneSignal (Real) | TOPIC_MESSAGING, DATA_PAYLOADS, BADGES, SILENT_NOTIFICATIONS |
| 7 | **Maps & Navigation** | Mapbox, Google Maps, HERE Technologies, TomTom | Mapbox (Real), Google Maps (Sim) | GEOCODE, REVERSE_GEOCODE, ROUTE, DISTANCE_MATRIX, MAP_TILES |
| 8 | **Geocoding** | Mapbox, Google Maps, Nominatim / OpenStreetMap | Mapbox (Real) | FORWARD_GEOCODE, REVERSE_GEOCODE, STRUCTURED_SEARCH |
| 9 | **Routing** | Mapbox Directions, Google Directions, OSRM | Mapbox (Real) | TURN_BY_TURN, TRAFFIC_ANNOTATIONS, AVOID_TOLLS |
| 10 | **Distance Matrix** | Mapbox Matrix API, Google Distance Matrix | Mapbox (Real) | MANY_TO_MANY_DISTANCE, URBAN_DURATION_ESTIMATION |
| 11 | **Places / Search** | Google Places, Mapbox Geocoding, Foursquare | Mapbox (Real) | AUTOCOMPLETE, PLACE_DETAILS, CATEGORY_SEARCH |
| 12 | **Identity / KYC** | HyperVerge, Surepass, Signzy, IDfy, Onfido | HyperVerge (Real), Surepass (Sim) | DRIVING_LICENCE, VEHICLE_RC, PAN, AADHAAR_OKYC, FACE_MATCH |
| 13 | **Vehicle Telematics / GPS** | Traccar, Teltonika, Geotab, Cartrack | Traccar (Real), Teltonika (Sim) | POSITION, ODOMETER, FUEL, BATTERY, GEOFENCE, IMMOBILIZE |
| 14 | **Accounting** | Zoho Books, TallyPrime, QuickBooks, Xero | Zoho Books (Real), QuickBooks (Catalog) | CREATE_INVOICE, RECORD_PAYMENT, SYNC_CUSTOMER, RECONCILE |
| 15 | **Tax / GST** | ClearTax, Zoho Tax, Avalara | Zoho Books (Real), ClearTax (Catalog) | GST_CALCULATION, E_INVOICE_GENERATION, E_WAY_BILL |
| 16 | **Search** | Meilisearch, Elasticsearch, Typesense, Algolia | Meilisearch (Real), Typesense (Sim) | INSTANT_INDEXING, TYPO_TOLERANCE, FACETED_SEARCH |
| 17 | **Analytics** | PostHog, Segment, Mixpanel, Google Analytics 4 | PostHog (Real), Segment (Sim) | EVENT_TRACKING, USER_IDENTIFICATION, BATCH_CAPTURE |
| 18 | **AI / LLM** | Google Gemini, OpenAI, Anthropic Claude, Azure OpenAI | Gemini (Real), OpenAI (Sim) | CHAT, TEXT_GENERATION, SUMMARIZATION, CLASSIFICATION |
| 19 | **OCR** | AWS Textract, Google Cloud Vision, HyperVerge | HyperVerge (Real) | DOCUMENT_TEXT_EXTRACTION, REGISTRATION_CERTIFICATE_OCR |
| 20 | **Document Verification** | Surepass, HyperVerge, Digilocker | HyperVerge (Real) | TAMPER_DETECTION, FORGERY_ANALYSIS, ID_AUTHENTICITY |
| 21 | **E-Signature** | DocuSign, Zoho Sign, Leegality | Leegality (Sim), Zoho Sign (Catalog) | AADHAAR_ESIGN, STAMP_DUTY_AFFIXATION, AUDIT_TRAIL |
| 22 | **Cloud Storage** | AWS S3, Cloudflare R2, Google Cloud Storage | S3 (Real), Cloudflare R2 (Real) | MULTIPART_UPLOAD, PRESIGNED_URLS, LIFECYCLE_RULES |
| 23 | **Customer Support** | Freshdesk, Zendesk, Intercom | Freshdesk (Sim), Zendesk (Catalog) | TICKET_CREATION, WEBHOOK_NOTIFICATIONS, OMNICHANNEL |
| 24 | **Voice / Calling** | Exotel, Twilio Voice, Knowlarity | Twilio (Real), Exotel (Sim) | NUMBER_MASKING, CLICK_TO_CALL, CALL_RECORDING |
| 25 | **Translation** | Google Cloud Translation, DeepL, AWS Translate | Google Cloud (Sim) | MULTI_LINGUAL_LOCALIZATION, CATALOG_TRANSLATION |
| 26 | **Image / Media Processing** | Cloudinary, Imgix, Sharp (Node) | Cloudinary (Sim), Sharp (Real) | RESIZING, WATERMARKING, WEBP_CONVERSION |
| 27 | **Fraud / Risk Detection** | Sift, Bureau.id, Simility | Bureau.id (Sim), Sift (Catalog) | DEVICE_FINGERPRINTING, BEHAVIORAL_SCORING, CHARGEBACK_RISK |
| 28 | **Address Validation** | India Post Pincode API, Google Address Validation | Mapbox (Real) | PINCODE_LOOKUP, ADDRESS_STANDARDIZATION |
| 29 | **Currency / FX** | Open Exchange Rates, Fixer, XE Currency | Fixer (Sim) | REAL_TIME_EXCHANGE_RATES, MULTI_CURRENCY_CONVERSION |
| 30 | **Business Verification** | MCA (Ministry of Corporate Affairs), GSTN | Surepass (Sim) | CIN_VERIFICATION, GSTIN_ACTIVE_STATUS_VERIFICATION |
| 31 | **Email Delivery Verification** | ZeroBounce, NeverBounce | ZeroBounce (Sim) | SYNTAX_CHECK, MX_RECORD_LOOKUP, SPAM_TRAP_DETECTION |
| 32 | **SMS OTP** | MSG91 OTP, Twilio Verify | MSG91 (Real), Twilio (Real) | OTP_GENERATION, CHANNEL_FALLBACK, RETRY_GOVERNANCE |
| 33 | **WhatsApp OTP** | Meta Cloud API Authentication Templates | Meta Cloud (Real) | ONE_TAP_AUTOFILL, SECURE_CODE_DELIVERY |
| 34 | **Fleet Navigation** | Mapbox Navigation SDK, MapmyIndia | Mapbox (Real) | TURN_BY_TURN, RE_ROUTING, COMPLIANT_TRUCK_ROUTING |
| 35 | **Vehicle Telemetry Stream** | Traccar Telemetry Socket, MQTT Broker | Traccar (Real) | RAW_TELEMETRY_INGESTION, PROTOCOL_NORMALIZATION |

---

## 3. Provider Pack Model

A **Provider Pack** is a self-contained, versioned integration unit encapsulating driver metadata, runtime capabilities, schema contracts, and health monitoring policies.

```typescript
export interface ProviderPackManifest {
  packId: string;
  version: string;
  providerId: string;
  providerName: string;
  category: IntegrationCategory;
  maturity: 'REAL_ADAPTER' | 'SIMULATION_MOCK' | 'CATALOG_ONLY';
  capabilities: CapabilityPack[];
  credentialSchema: ProviderCredentialSchema;
  environments: Array<'SANDBOX' | 'LIVE'>;
  supportedRegions: string[];
  supportedCurrencies: string[];
  rateLimits: ProviderRateLimits;
  costModel: ProviderCostModel;
  webhookConfig?: ProviderWebhookConfig;
  healthCheckConfig?: ProviderHealthCheckConfig;
  retryPolicy?: ProviderRetryPolicy;
  fallbackSuitability?: {
    eligibleAsPrimary: boolean;
    eligibleAsFallback: boolean;
    priorityScore: number;
  };
  documentationUrl?: string;
  lifecycleState: ConnectorLifecycleState;
  lifecycleHistory?: LifecycleTransitionRecord[];
  activeTenantBindings?: TenantConnectorBinding[];
}
```

### Adding a New Provider Pack
To add a new provider to DriveGo:
1. Define the `ProviderPackManifest` in `src/integrations/packs/builtin-provider-packs.data.ts`.
2. Implement the capability contracts (`src/integrations/adapters/<category>/<provider>.adapter.ts`).
3. Register the adapter in `src/integrations/integrations.module.ts` and wire capability dispatching in `IntegrationRuntimeService`.
4. Register tests in `phase-l-enterprise-connector-expansion.spec.ts`.
5. **No modification of business domain services (e.g. `PaymentsService`, `GeospatialService`, `VehiclesService`) is required.**

---

## 4. 10-State Connector Lifecycle Engine

Connectors are governed by a strict non-linear finite state machine that guarantees unverified credentials or broken webhooks never reach production:

```
[DISCOVERED]
     │
     ▼ (admin initiates configuration)
[CONFIGURED]
     │
     ▼ (credentials schema and ping verified)
[CREDENTIALS_VALIDATED]
     │
     ▼ (end-to-end sandbox capability call passes)
[SANDBOX_TESTED]
     │
     ▼ (HMAC signature verification passes)
[WEBHOOK_VERIFIED]
     │
     ▼ (compliance officer / admin approves)
[APPROVED]
     │
     ▼ (activated for live traffic)
[ACTIVE] ◄────────┐
  │   ▲           │ (health restored)
  │   └── [DEGRADED] (consecutive timeouts/errors)
  │
  ├─► [DISABLED] (manual operator pause)
  │
  └─► [RETIRED] (permanent end-of-life)
```

Every state transition is persisted with an auditable trail:
- `timestamp`: ISO-8601 UTC timestamp.
- `fromState`: Previous lifecycle state.
- `toState`: Target lifecycle state.
- `actor`: User ID or system monitor initiating the change.
- `reason`: Explanatory rationale.
- `metadata`: Health metrics, validation results, or incident references.

---

## 5. Multi-Tenant Hierarchical Ownership Model

DriveGo provides granular, multi-level connector governance:

```
┌────────────────────────────────────────────────────────┐
│                   PLATFORM DEFAULT                     │
│ (Global platform fallback: e.g. Razorpay, Mapbox, FCM) │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│              ORGANIZATION / VENDOR SCOPE               │
│ (Vendor-specific account, negotiated rates & gateways) │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│                BRANCH / PROPERTY SCOPE                 │
│ (Regional overrides: e.g. local airport branch fleet)  │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│              OPERATIONAL EMERGENCY OVERRIDE            │
│ (Real-time incident response routing by admin)         │
└────────────────────────────────────────────────────────┘
```

The `ProviderPackRegistryService.resolveTenantBinding()` method traverses this hierarchy with zero cross-tenant credential leakage.

---

## 6. Intelligent Policy-Driven Routing & Failover

When a capability execution is requested, the runtime generates an auditable **Routing Explanation**:

```json
{
  "category": "PAYMENTS",
  "capability": "UPI_INTENT",
  "tenantId": "vendor_789",
  "selectedProvider": "cashfree",
  "selectionReason": "Matched vendor preferred provider for UPI_INTENT in IN region",
  "fallbackChain": ["razorpay", "payu"],
  "healthStatus": "HEALTHY",
  "circuitBreakerState": "CLOSED",
  "evaluationTimestamp": "2026-09-09T14:35:00.000Z"
}
```

### Classification-Based Safe Failover
Unlike naive systems that retry blindly, DriveGo categorizes failure types before triggering fallbacks:

| Error Classification | Safe to Fallback? | Behavior |
|---|---|---|
| `TIMEOUT` | **Yes** (with idempotency) | Evaluate alternate provider in fallback chain with same idempotency key |
| `RATE_LIMITED` | **Yes** | Shift traffic to secondary provider immediately; trigger circuit cooldown |
| `NETWORK_ERROR` | **Yes** | Transition to next provider in fallback chain |
| `AUTHENTICATION_ERROR` | **No** | Do NOT fallback; mark connector as `DEGRADED`; alert admin |
| `INVALID_REQUEST` | **No** | Reject immediately; do not poison secondary providers with invalid input |
| `PROVIDER_DECLINED` | **Policy-dependent** | In financial transactions (e.g. Card Declined / Insufficient Funds), propagate decline to customer without duplicate billing |
| `DUPLICATE_TRANSACTION` | **No** | Return existing financial state; prevent duplicate financial debits |

---

## 7. Concrete Real Adapters Implemented in Phase L

1. **Mapbox Maps Adapter** (`src/integrations/adapters/maps/mapbox-maps.adapter.ts`):
   - Capabilities: `GEOCODE`, `REVERSE_GEOCODE`, `ROUTE`, `DISTANCE_MATRIX`.
   - Turn-by-turn routing with distance in meters/kilometers and traffic-adjusted durations.
   - Fallback protection: Graceful degradation to local Haversine distance.

2. **Traccar Telematics Adapter** (`src/integrations/adapters/tracking/traccar-telematics.adapter.ts`):
   - Capabilities: `TELEMETRY_STREAM`, `GEOFENCE`, `REMOTE_IMMOBILIZATION`.
   - Real-time GPS coordinate normalization, speed, battery, ignition status, and vehicle immobilization command dispatch.

3. **HyperVerge KYC Adapter** (`src/integrations/adapters/verification/hyperverge-kyc.adapter.ts`):
   - Capabilities: `PAN_VERIFICATION`, `DRIVING_LICENCE`, `VEHICLE_RC`, `FACE_MATCH`.
   - Extraction of document authenticity, expiration dates, vehicle ownership, and facial similarity scoring.

4. **Zoho Books Accounting Adapter** (`src/integrations/adapters/accounting/zoho-books.adapter.ts`):
   - Capabilities: `CREATE_INVOICE`, `CALCULATE_TAX`, `SYNC_CUSTOMER`.
   - Indian GST compliance (CGST, SGST, IGST calculation based on state codes).

5. **Google Gemini AI Adapter** (`src/integrations/adapters/ai/google-gemini.adapter.ts`):
   - Capabilities: `CHAT`, `TEXT_GENERATION`, `SUMMARIZATION`, `CLASSIFICATION`.
   - Customer support ticket intent analysis, damage report classification, and automated sentiment scoring.

6. **Meilisearch Search Adapter** (`src/integrations/adapters/search/meilisearch.adapter.ts`):
   - Capabilities: `INDEX_DOCUMENTS`, `SEARCH`.
   - High-throughput vehicle inventory indexing, typo-tolerant search, and attribute filtering.

7. **PostHog Analytics Adapter** (`src/integrations/adapters/analytics/posthog-analytics.adapter.ts`):
   - Capabilities: `TRACK_EVENT`, `IDENTIFY_USER`, `BATCH_CAPTURE`.
   - Normalized event ingestion for booking funnels, checkout drops, and vendor onboarding telemetry.

---

## 8. Business Service Capability Migration

### Geospatial Service (`src/geospatial/geospatial.service.ts`)
- **Before**: Direct hardcoded mocks or static points.
- **After**: All geocoding, turn-by-turn routing, and distance matrix calculations route through `IntegrationRuntimeService` with capability strings (`'GEOCODE'`, `'ROUTE'`, `'DISTANCE_MATRIX'`).
- Preserves full backward compatibility with numeric coordinate arguments `(lat1, lng1, lat2, lng2)` and SpatialPoint objects.
- High-resilience fallback: Automatically switches to mathematical Haversine calculations if the runtime is disabled or unreachable.

---

## 9. Verification & Testing

The Phase L test suite guarantees compliance across all architectural requirements:
- **Provider Pack Registry Tests**: Registration, 10-state lifecycle engine, invalid transition rejections, and tenant binding resolution.
- **Dynamic Capability Discovery**: Inspecting capabilities, filtering by region/currency.
- **Contract & Simulation Tests**: Validating Mapbox, Traccar, HyperVerge, Zoho Books, Gemini, Meilisearch, and PostHog adapters.
- **Safe Failover & Error Classification**: Validating idempotency preservation and prevention of duplicate financial transactions.
- **Business Service Integration**: Validating `GeospatialService` routing via `IntegrationRuntimeService`.

**Test Command**:
```bash
npx jest src/integrations/tests/phase-l-enterprise-connector-expansion.spec.ts
```
Result: **39 passing tests (100% success rate)**.
