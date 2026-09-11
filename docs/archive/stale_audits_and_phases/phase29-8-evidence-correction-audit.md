# DriveGo Phase 29.8 — Evidence Correction & Classification Audit

## Executive Summary
This document provides an honest, rigorous audit and classification of the Phase 29.8 evidence artifacts in accordance with DriveGo Engineering Quality Standards.

---

## 1. Previous Evidence Problem Analysis

In the initial Phase 29.8 execution, visual evidence was generated using Flutter's test environment (`apps/vendor_app/test/phase29_8_evidence_capture_test.dart`) via `RenderRepaintBoundary.toImage()` and widget tree pump cycles. 

While these tests verified widget composition and layout constraints, they did **not** capture the genuine Android runtime behavior of the actual compiled APK running on the Android Virtual Device (`emulator-5554`).

### Evidence Classification Matrix (Previous vs Corrected)

| Evidence Item | Previous Origin | Classification | Corrected Origin | Corrected Classification |
|---|---|---|---|---|
| `01_vendor_dashboard.png` | Widget Test (`phase29_8_evidence_capture_test.dart`) | `TEST-HARNESS` | Android AVD (`screencap` on `emulator-5554`) | `LIVE AVD VERIFIED` |
| `02_action_required.png` | Widget Test (`phase29_8_evidence_capture_test.dart`) | `TEST-HARNESS` | Android AVD (`screencap` on `emulator-5554`) | `LIVE AVD VERIFIED` |
| `03_booking_attention.png` | Widget Test (`phase29_8_evidence_capture_test.dart`) | `TEST-HARNESS` | Android AVD (`screencap` on `emulator-5554`) | `LIVE AVD VERIFIED` |
| `04_todays_operations.png` | Widget Test (`phase29_8_evidence_capture_test.dart`) | `TEST-HARNESS` | Android AVD (`screencap` on `emulator-5554`) | `LIVE AVD VERIFIED` |
| `05_fleet_snapshot.png` | Widget Test (`phase29_8_evidence_capture_test.dart`) | `TEST-HARNESS` | Android AVD (`screencap` on `emulator-5554`) | `LIVE AVD VERIFIED` |
| `06_earnings_snapshot.png` | Widget Test (`phase29_8_evidence_capture_test.dart`) | `TEST-HARNESS` | Android AVD (`screencap` on `emulator-5554`) | `LIVE AVD VERIFIED` |
| `07_notifications.png` | Widget Test (`phase29_8_evidence_capture_test.dart`) | `TEST-HARNESS` | Android AVD (`screencap` on `emulator-5554`) | `LIVE AVD VERIFIED` |
| `08_support_entry.png` | Widget Test (`phase29_8_evidence_capture_test.dart`) | `TEST-HARNESS` | Android AVD (`screencap` on `emulator-5554`) | `LIVE AVD VERIFIED` |
| `09_booking_destination.png` | Widget Test (`phase29_8_evidence_capture_test.dart`) | `TEST-HARNESS` | Android AVD (`screencap` on `emulator-5554`) | `LIVE AVD VERIFIED` |
| `10_fleet_destination.png` | Widget Test (`phase29_8_evidence_capture_test.dart`) | `TEST-HARNESS` | Android AVD (`screencap` on `emulator-5554`) | `LIVE AVD VERIFIED` |

---

## 2. Separation of Test-Harness Evidence
All previous test-harness evidence files have been segregated into:
`docs/evidence/phase29-8-vendor-operations-dashboard/test-harness/`

The primary evidence directory `docs/evidence/phase29-8-vendor-operations-dashboard/` will contain strictly genuine Android AVD screenshots with the `*_avd.png` naming pattern.

---

## 3. Target Android Runtime Environment
- **Device Identifier**: `emulator-5554`
- **Android Version**: Android 16 (`ro.build.version.release = 16`)
- **Display Resolution**: `1080 x 2424`
- **Pixel Density**: `420 dpi` (xxdpi scaling)
- **Application Package**: `com.example.vendor_app`
