# DriveGo — Provider Readiness & Gateway Catalog Matrix (44 Gateways across 12 Categories)

## 1. Executive Summary
This specification documents all 44 verified gateways across 12 infrastructure categories integrated into the DriveGo Control Tower. Every gateway is evaluated on:
- Integration Status (`LIVE_READY`, `ADAPTER_IMPLEMENTED`, `CONTRACT_READY`, `CATALOG_ONLY`).
- Health Status & Telemetry (`HEALTHY`, `DEGRADED`, `CIRCUIT_OPEN`).
- Baseline SLA Delivery Rate (%) & Latency.
- Cost Structure (INR / USD / EUR).
- Geographic Scope & Multi-Tenant Capabilities.

---

## 2. 12-Category Gateway Master Matrix

### Category 1: WhatsApp Business Messaging
| Provider ID | Gateway Name | Integration Status | Health | Delivery SLA | Avg Latency | Cost Model | Geographies | Supported Capabilities |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `meta` | **Meta WhatsApp Cloud API** *(Primary)* | `LIVE_READY` | `HEALTHY` | 99.4% | 38 ms | ₹0.45 / conv | IN, AE, US, GB, SG | Dynamic Templates, Rich Media, Handover OTP, Read Receipts |
| `gupshup_whatsapp` | **Gupshup WhatsApp Enterprise** *(Failover)* | `ADAPTER_IMPLEMENTED` | `HEALTHY` | 98.9% | 45 ms | ₹0.48 / conv | IN, AE, SG | DLT Headers, Media Payload, Delivery Callbacks |
| `twilio_whatsapp` | **Twilio for WhatsApp** | `CONTRACT_READY` | `HEALTHY` | 99.1% | 62 ms | $0.0075 / msg | Global | Session Messaging, Fallback Chain |
| `infobip_whatsapp` | **Infobip WhatsApp Business** | `CONTRACT_READY` | `HEALTHY` | 99.2% | 55 ms | €0.0080 / msg | EU, AE, IN | Omni-Failover, Enterprise SLA |

### Category 2: SMS (India DLT Compliant)
| Provider ID | Gateway Name | Integration Status | Health | Delivery SLA | Avg Latency | Cost Model | Geographies | Supported Capabilities |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `msg91` | **MSG91 India DLT** *(Primary)* | `LIVE_READY` | `HEALTHY` | 99.8% | 22 ms | ₹0.14 / msg | IN | DLT Header (DRIVGO), 5-Sec OTP Route, Flow Webhooks |
| `twilio_sms_in` | **Twilio India SMS** *(Failover)* | `LIVE_READY` | `HEALTHY` | 99.2% | 42 ms | ₹0.18 / msg | IN | Programmable Messaging, Status Callback |
| `gupshup_sms` | **Gupshup India SMS** | `ADAPTER_IMPLEMENTED` | `HEALTHY` | 98.8% | 35 ms | ₹0.15 / msg | IN | DLT Template Match, High Throughput Bulk |
| `exotel_sms` | **Exotel Transactional SMS** | `CONTRACT_READY` | `HEALTHY` | 99.0% | 32 ms | ₹0.16 / msg | IN | Priority OTP, Transactional Alerts |
| `twofactor_sms` | **2Factor Dedicated SMS OTP** | `CONTRACT_READY` | `HEALTHY` | 99.7% | 18 ms | ₹0.18 / otp | IN | Dedicated Sub-5s Verification Route |
| `karix_sms` | **Karix Mobile SMS** | `CONTRACT_READY` | `HEALTHY` | 99.1% | 30 ms | ₹0.15 / msg | IN | Banking-Grade DLT, Telco Aggregator |
| `routemobile_sms`| **Route Mobile SMS** | `CONTRACT_READY` | `HEALTHY` | 98.6% | 34 ms | ₹0.15 / msg | IN, AE | Direct Carrier Interconnect |
| `valuefirst_sms`| **ValueFirst (Twilio) SMS** | `CONTRACT_READY` | `HEALTHY` | 98.4% | 38 ms | ₹0.14 / msg | IN | Multi-Telco Failover |
| `tanla_sms` | **Tanla Platforms Wisely** | `CONTRACT_READY` | `HEALTHY` | 99.5% | 25 ms | ₹0.16 / msg | IN | Blockchain DLT Audit, Zero Spam Scrubbing |
| `textlocal_sms` | **Textlocal India** | `CATALOG_ONLY` | `HEALTHY` | 98.0% | 45 ms | ₹0.16 / msg | IN | Inbox Reporting |
| `fast2sms` | **Fast2SMS Quick Gateway** | `CATALOG_ONLY` | `HEALTHY` | 97.5% | 55 ms | ₹0.12 / msg | IN | Prepaid Wallet Topup Route |

### Category 3: SMS (Global International)
| Provider ID | Gateway Name | Integration Status | Health | Delivery SLA | Avg Latency | Cost Model | Geographies | Supported Capabilities |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `twilio_global_sms` | **Twilio Global Messaging** *(Primary)* | `LIVE_READY` | `HEALTHY` | 99.6% | 38 ms | $0.0079 / msg | Global (180+ countries) | Global Alphanumeric Sender IDs |
| `sinch_sms` | **Sinch Global SMS** | `ADAPTER_IMPLEMENTED` | `HEALTHY` | 99.3% | 40 ms | $0.0075 / msg | US, EU, APAC | Direct Tier-1 Carrier Routes |
| `infobip_global_sms`| **Infobip Global SMS** | `CONTRACT_READY` | `HEALTHY` | 99.4% | 36 ms | €0.0070 / msg | EU, MENA, LATAM | Compliance Filtering |
| `aws_sns_sms` | **Amazon SNS Worldwide SMS** | `CONTRACT_READY` | `HEALTHY` | 99.1% | 48 ms | $0.0065 / msg | Global | AWS IAM Integration, Multi-Region |
| `vonage_sms` | **Vonage (Nexmo) SMS** | `CONTRACT_READY` | `HEALTHY` | 98.9% | 44 ms | €0.0068 / msg | Global | Adaptive Routing Engine |
| `plivo_sms` | **Plivo SMS API** | `CONTRACT_READY` | `HEALTHY` | 99.0% | 42 ms | $0.0055 / msg | US, CA, Global | Cost-Optimized Route |
| `bird_sms` | **Bird (MessageBird) SMS** | `CATALOG_ONLY` | `HEALTHY` | 98.7% | 50 ms | €0.0080 / msg | EU, US | Omnichannel Conversation Sync |

### Category 4: Transactional & Lifecycle Email
| Provider ID | Gateway Name | Integration Status | Health | Delivery SLA | Avg Latency | Cost Model | Geographies | Supported Capabilities |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `resend` | **Resend Transactional Email** *(Primary)* | `LIVE_READY` | `HEALTHY` | 99.9% | 65 ms | $0.0001 / email | Global | React Email Templates, Domain DKIM/SPF Verification |
| `aws_ses` | **Amazon SES** *(Secondary)* | `LIVE_READY` | `HEALTHY` | 99.8% | 85 ms | $0.10 / 1000 | Global | Dedicated IPs, High-Scale Throughput |
| `sendgrid` | **Twilio SendGrid** *(Failover)* | `ADAPTER_IMPLEMENTED` | `HEALTHY` | 99.4% | 90 ms | $0.0008 / email | Global | Dynamic Templates, Unsubscribe Groups |
| `postmark` | **Postmark by ActiveCampaign** | `CONTRACT_READY` | `HEALTHY` | 99.9% | 45 ms | $0.0012 / email | Global | Dedicated Transactional Delivery (<10s inbox) |
| `mailgun` | **Mailgun by Sinch** | `CATALOG_ONLY` | `HEALTHY` | 99.2% | 95 ms | $0.0008 / email | Global | Advanced Email Validation |

### Category 5: Mobile Push Notifications
| Provider ID | Gateway Name | Integration Status | Health | Delivery SLA | Avg Latency | Cost Model | Geographies | Supported Capabilities |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `fcm` | **Firebase Cloud Messaging (FCM)** *(Primary)* | `LIVE_READY` | `HEALTHY` | 99.8% | 18 ms | Free | Global | Android & iOS APNs, Topic Broadcasts, Silent Data Payloads |
| `onesignal` | **OneSignal Mobile Push** *(Failover)* | `ADAPTER_IMPLEMENTED` | `HEALTHY` | 99.3% | 25 ms | $0.0001 / msg | Global | Automated Retries, Intelligent Delivery Timing |
| `amazon_sns_push`| **Amazon SNS Mobile Push** | `CONTRACT_READY` | `HEALTHY` | 99.6% | 22 ms | $0.00005 / msg | Global | Massive Fan-Out Scale |
| `airship` | **Airship (Urban Airship)** | `CATALOG_ONLY` | `HEALTHY` | 99.1% | 35 ms | $0.0002 / msg | Global | Geofence Push Triggers |

### Category 6: Voice & Voice OTP
| Provider ID | Gateway Name | Integration Status | Health | Delivery SLA | Avg Latency | Cost Model | Geographies | Supported Capabilities |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `twilio_voice` | **Twilio Programmable Voice** *(Primary)* | `ADAPTER_IMPLEMENTED` | `HEALTHY` | 99.2% | 52 ms | $0.015 / min | US, IN, EU | Text-to-Speech Voice OTP, Call Recording |
| `exotel_voice` | **Exotel Cloud Telephony** *(Failover)* | `CONTRACT_READY` | `HEALTHY` | 99.0% | 45 ms | ₹0.75 / min | IN | Number Masking (Customer-Vendor Privacy), IVR Dispatch |
| `vonage_voice` | **Vonage Voice API** | `CONTRACT_READY` | `HEALTHY` | 98.7% | 58 ms | €0.014 / min | Global | Synthesized Speech, PSTN Fallback |

### Category 7: Payments & Nodal Escrow Settlement
| Provider ID | Gateway Name | Integration Status | Health | Settlement SLA | Fee Model | Capabilities |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `razorpay` | **Razorpay Route & Smart Collect** *(Primary)* | `LIVE_READY` | `HEALTHY` | T+1 Escrow Split | 2.0% + GST | UPI AutoPay, Security Deposit Pre-Auth, Vendor Escrow Transfers |
| `cashfree` | **Cashfree EasySplit & Verification** *(Secondary)* | `LIVE_READY` | `HEALTHY` | Instant / T+1 | 1.8% + GST | Instant Bank Account Payouts, Penny-Drop Bank Verification |
| `stripe` | **Stripe Connect** | `ADAPTER_IMPLEMENTED` | `HEALTHY` | T+2 Rolling | 2.9% + 30¢ | International Cards, Corporate Cards |
| `payu` | **PayU Marketplace Escrow** | `CONTRACT_READY` | `HEALTHY` | T+2 | 2.0% + GST | Nodal Escrow Accounts |

### Category 8: Identity & KYC Verification
| Provider ID | Gateway Name | Integration Status | Health | Verification SLA | Capabilities |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `setu_digilocker` | **Setu DigiLocker Gateway** *(Primary)* | `LIVE_READY` | `HEALTHY` | < 10 seconds | Instant Driving Licence & Aadhaar verification direct from MoRTH |
| `hyperverge` | **HyperVerge AI Verification** | `ADAPTER_IMPLEMENTED` | `HEALTHY` | < 5 seconds | Real-time Liveness Check, OCR Document Extraction, Face Match |
| `cashfree_kyc` | **Cashfree Verification Suite** | `ADAPTER_IMPLEMENTED` | `HEALTHY` | < 3 seconds | UPI ID Verification, Bank Account Name Match, Pan Verification |

### Category 9: Telematics & GPS Fleet Tracking
| Provider ID | Gateway Name | Integration Status | Health | Frequency | Capabilities |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `loconav` | **LocoNav IoT Telematics** *(Primary)* | `LIVE_READY` | `HEALTHY` | 10 seconds | Real-time GPS, Ignition On/Off, Geofence In/Out alerts, Odometer sync |
| `fleetx` | **Fleetx Intelligent Telematics** | `ADAPTER_IMPLEMENTED` | `HEALTHY` | 15 seconds | Fuel monitoring, Remote Engine Immobilizer, Rash Driving score |
| `traccar` | **Traccar Open Telematics Server** | `CONTRACT_READY` | `HEALTHY` | 5 seconds | Direct OBD-II device support, Self-hosted private telemetry |

### Category 10: Cloud Object Storage
| Provider ID | Gateway Name | Integration Status | Health | Redundancy | Capabilities |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `aws_s3` | **Amazon Web Services S3** *(Primary)* | `LIVE_READY` | `HEALTHY` | 99.999999999% | Inspection photo evidence, encrypted KYC documents, signed URLs |
| `cloudflare_r2`| **Cloudflare R2 Storage** *(Secondary)* | `ADAPTER_IMPLEMENTED` | `HEALTHY` | 99.99% | Zero egress fees, high-speed edge CDN for public vehicle photos |
| `gcs` | **Google Cloud Storage** | `CONTRACT_READY` | `HEALTHY` | 99.999999999% | Vertex AI document processing integration |

### Category 11: Maps, Geocoding & Routing
| Provider ID | Gateway Name | Integration Status | Health | Accuracy | Capabilities |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `google_maps` | **Google Maps Platform** *(Primary)* | `LIVE_READY` | `HEALTHY` | Global #1 | Places Autocomplete, Geocoding, Distance Matrix, Polylines |
| `mapbox` | **Mapbox Vector Maps & Navigation** | `ADAPTER_IMPLEMENTED` | `HEALTHY` | Vector 60fps | Custom dark map styles, Offline tile caching, Turn-by-turn nav |
| `ola_maps` | **Ola Maps Platform** | `CONTRACT_READY` | `HEALTHY` | India Localized | Hyperlocal Indian address matching, cost-effective API tiers |

### Category 12: Accounting & Invoicing ERP
| Provider ID | Gateway Name | Integration Status | Health | Sync | Capabilities |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `zoho_books` | **Zoho Books India GST API** *(Primary)* | `ADAPTER_IMPLEMENTED` | `HEALTHY` | Real-time | Automated GST tax invoices (B2C & B2B), E-Way bill generation |
| `quickbooks` | **Intuit QuickBooks Online** | `CONTRACT_READY` | `HEALTHY` | Hourly batch | Multi-currency ledger consolidation |
