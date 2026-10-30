# DRIVEGO — APP STORE & PLAY STORE READINESS SPECIFICATION
## Apple App Store Guidelines, Google Play Policies & Mobile Distribution Readiness

> **Document Reference**: `docs/architecture/APP_STORE_AND_PLAY_STORE_READINESS.md`  
> **Classification**: Mobile Application Distribution Standard  
> **Status**: APPROVED — PRODUCTION BLUEPRINT  
> **Author**: DriveGo Mobile Engineering & Store Governance Team  

---

## 1. APPLE APP STORE GUIDELINES COMPLIANCE

| Guideline | Policy Requirement | DriveGo Architectural Compliance | Verification Status |
|---|---|---|---|
| **5.1.1(v) Account Deletion** | Apps supporting account creation must provide an easy, self-service account deletion mechanism. | Implemented in Profile Settings -> Security -> Delete Account. Initiates 30-day grace period, followed by automated anonymization via `anonymizeUser()`. | **COMPLIANT** |
| **3.1.5(a) Physical Services Exemption** | Goods and services consumed outside of the app are exempt from In-App Purchases (IAP). | Vehicle rental is a physical transportation service. Standard payment gateways (Razorpay, Cards, UPI) are 100% compliant. | **COMPLIANT** |
| **5.1.2 Data Use & Privacy** | App Privacy Nutrition Labels must accurately declare data collection and tracking. | Declared: Precise Location (car search/hub navigation), Camera (inspection photos), Financial Details (payments). | **COMPLIANT** |
| **2.1 App Completeness** | Submissions must be complete without placeholder text, broken links, or fake data. | All 3 client applications render real backend data with responsive DDS widgets and verified empty states. | **COMPLIANT** |

---

## 2. GOOGLE PLAY STORE POLICY COMPLIANCE

| Policy Domain | Requirement | DriveGo Implementation | Verification Status |
|---|---|---|---|
| **Target SDK Version** | Must target Android 14 (API level 34) or higher. | Target SDK configured to API 34 in `android/app/build.gradle`. | **COMPLIANT** |
| **Foreground Service Location** | `FOREGROUND_SERVICE_LOCATION` requires user-facing utility during active use. | Used exclusively during active rental trip navigation and proximity detection to pickup hubs. | **COMPLIANT** |
| **Prominent Disclosure** | Runtime permissions (Location, Camera) require prominent in-app disclosure prior to OS prompt. | Pre-permission modal dialogs display user benefits before triggering Android runtime permission requests. | **COMPLIANT** |
| **Data Safety Section** | Accurate declaration of collected and encrypted fields. | All collected customer data is encrypted in transit (TLS 1.3) and encrypted at rest (AES-256). | **COMPLIANT** |

---

## 3. STORE PERMISSION DECLARATIONS & STRINGS

```xml
<!-- AndroidManifest.xml (Customer & Vendor Apps) -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
```

```xml
<!-- Info.plist (iOS Customer & Vendor Apps) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>DriveGo uses your location to discover nearby rental cars, calculate delivery fees, and navigate you to the pickup hub.</string>
<key>NSCameraUsageDescription</key>
<string>DriveGo requires camera access to capture pre-trip and post-trip vehicle inspection photos and verify your driving license.</string>
```

---
*Ratified by DriveGo Mobile Engineering & Store Governance Team.*

