# Phase 29.17: Visual Evidence Manifest

**Audit Target**: Phase 29.17 Cross-Platform Fulfillment Production Integration & System Hardening
**Capture Environment**: Android Emulator (`emulator-5554`, Google Pixel 9, Android 16 / API 36, WHPX Acceleration) & High-DPI Flutter Pixel-Boundary Harness
**Viewport / Resolution**: 1080 x 2400 (DPI: 1.0 / Pixel 9 physical aspect)
**Date**: 2026-09-04

---

## Evidence Manifest Table

| Screenshot Filename | Screen / Flow | Expected Behavior | Observed Behavior | File Size |
|---|---|---|---|---|
| `01_host_yard_handover_staging.png` | Vendor Booking Detail — Host Yard Staging | Shows `HUB_PICKUP` badge, host yard address (`Sector 4, Andheri East`), pickup fee ₹0, and "Ready for Handover" staging action. | Displays exact snapshot data, host yard banner, and action button without coordinate leakage. | 43,141 B |
| `02_doorstep_dispatch_coordinates.png` | Vendor Booking Detail — Doorstep Delivery | Shows `DOORSTEP_DELIVERY` badge, doorstep delivery address, delivery fee (₹450), persisted GPS lat/lng (19.0178, 72.8178), and Google Maps navigation action. | GPS coordinates correctly bound; navigation action enabled; fees match authoritative quote. | 45,468 B |
| `03_transit_hub_arrival_banner.png` | Vendor Booking Detail — Airport / Transit Hub | Shows `PUBLIC_LOCATION` badge, CSMIA Terminal 2 arrivals pick-up zone, itemized pickup & return hub fees (₹200 each). | Public location banner rendered cleanly with terminal instructions and itemized fee breakdown. | 46,939 B |
| `04_handover_pre_trip_inspection.png` | Handover Wizard — Pre-Trip Inspection | Form validates initial odometer (>= 0), fuel percentage (100%), exterior damage checklist, and photo evidence before handover. | Pre-trip inspection checklist rendered; odometer baseline recorded for monotonic validation. | 26,322 B |
| `05_handover_otp_verification.png` | Handover Wizard — Review & OTP Verification | Displays 6-digit OTP entry field; prevents state progression to `ongoing` if OTP is invalid or missing. | Customer OTP verification step rendered; enforces security gate before vehicle release. | 23,933 B |
| `06_active_rental_ongoing.png` | Vendor Booking Detail — Active Ongoing Rental | Status is `ongoing`; vehicle is marked unavailable in fleet; shows "Trip in Progress" banner and return staging action. | Shows ongoing rental state; all 13 snapshot fields remain identical to booking creation. | 44,809 B |
| `07_return_inspection_odometer.png` | Return Wizard — Post-Trip Inspection | Enforces monotonic odometer rule (must be >= handover odometer); checks fuel percent and condition notes. | Return inspection form rendered; odometer validation rule prevents odometer rollback. | 29,387 B |
| `08_completed_booking_immutable_snapshot.png` | Vendor Booking Detail — Completed Booking | Status is `completed`; displays all 13 immutable snapshot fields; vehicle availability restored or maintenance-locked. | Completed booking view retains historical fulfillment snapshot with zero mutations. | 46,018 B |
| `09_different_return_branch_relocation.png` | Vendor Booking Detail — Relocation Branch | Shows different return branch (`hub_bkc`), relocation one-way fee (₹350), and branch return address. | Relocation branch details clearly separated from pickup branch; oneWayFee displayed accurately. | 43,546 B |
| `10_combined_doorstep_branch_return.png` | Vendor Booking Detail — Doorstep + Hub Return | Outbound: Doorstep delivery (₹500); Inbound: Branch return (`hub_vashi`, ₹200); Relocation: ₹400. Zero cross-contamination. | Both modes rendered with independent addresses, fees, and coordinates without cross-contamination. | 47,348 B |
