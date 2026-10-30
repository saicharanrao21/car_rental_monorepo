# DRIVEGO — OPERATIONS AND SUPPORT STANDARD OPERATING PROCEDURES (SOP)

**Document ID:** `DRV-SOP-2026-009`  
**Version:** 1.0.0  
**Effective Date:** October 29, 2026  
**Auditor:** Operations Architect & Customer Care Lead  
**Scope:** Marketplace Operations, Fleet Handover, Incident Response, and Financial Control

---

## SOP-OPS-01: Booking Monitoring & Handover Readiness

- **Target Audience:** Booking Operations Executives, Hub Managers.
- **Trigger:** Continuous operating window (24/7).
- **Procedure:**
  1. Monitor `/operations-center` for pickups scheduled in the next 2 hours.
  2. Verify that the assigned vehicle is present at the designated Operating Yard with battery/fuel >80% and clean interior.
  3. If vehicle is delayed or defective:
     - Re-allocate identical or superior category car from the same yard within 10 minutes.
     - Dispatch WhatsApp alert to customer informing them of the upgrade at no additional charge.
     - Notify the host partner with an SLA warning.

---

## SOP-OPS-02: Overdue Vehicle Return & Asset Recovery

- **Target Audience:** Recovery Team, Operations Manager.
- **Trigger:** Automated trigger when booking return time exceeds +30 minutes without customer-initiated trip extension.
- **Procedure:**
  1. Automated WhatsApp / SMS warning dispatched to customer (+30m): Prompt to extend trip via app or return immediately.
  2. Telephonic outreach (+60m): Customer support calls renter. If phone unreachable, emergency contact called.
  3. Escalation (+120m):
     - Incur hourly penalty fees automatically via `job_overdue_scan`.
     - Notify Vendor Host.
  4. Asset Protection (+240m):
     - If renter remains unresponsive, Operations Manager authorizes telematics engine immobilization when the vehicle comes to a complete halt.
     - Dispatch field recovery team to GPS coordinates.
     - File formal police complaint with vehicle documents and booking audit trail.

---

## SOP-OPS-03: Emergency SOS & Roadside Assistance Dispatch

- **Target Audience:** Emergency Dispatch Executive on duty.
- **Trigger:** Customer taps "SOS Emergency" in customer app or calls emergency hotline.
- **SLA:** Initial response within **< 30 seconds**.
- **Procedure:**
  1. Open `/emergency-dispatch` console immediately.
  2. Initiate outbound phone call to renter to assess safety, medical status, and location.
  3. If medical emergency or severe collision:
     - Dispatch 108 Ambulance and 112 Police immediately to real-time coordinates.
     - Notify customer's pre-configured emergency contacts via automated SMS/WhatsApp broadcast.
  4. If mechanical breakdown on highway:
     - Dispatch DriveGo roadside towing partner (TVS Auto Assist / Allianz partner).
     - Arrange alternative cab (Uber for Business / local partner) to transport renter to destination.
     - Freeze rental billing from breakdown timestamp.

---

## SOP-OPS-04: Damage Claim & Deposit Deduction Adjudication

- **Target Audience:** Claims Specialist, Finance Executive.
- **Trigger:** Host reports damage upon vehicle return and submits repair bill estimate.
- **SLA:** Adjudication within **< 48 hours**.
- **Procedure:**
  1. Compare pre-trip inspection photographs against return inspection photographs in `/disputes`.
  2. Verify damage was not pre-existing.
  3. Verify host has provided an authorized workshop GST estimate.
  4. Check customer's protection package:
     - Basic Protection: Customer liable up to deposit limit (e.g., ₹5,000); balance covered by host commercial insurance.
     - Zero Liability Protection: Customer liability capped at ₹0 (unless gross negligence / drunk driving).
  5. Submit deduction request via `ApprovalEngineService` requiring dual signoff.
  6. Upon approval, deduct exact sanctioned amount from security deposit and refund remaining balance immediately.

