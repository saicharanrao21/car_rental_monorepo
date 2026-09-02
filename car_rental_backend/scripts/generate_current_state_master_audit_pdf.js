const fs = require('fs');
const path = require('path');
const PDFDocument = require('pdfkit');

function generateMasterAuditPDF() {
  const doc = new PDFDocument({
    size: 'A4',
    margin: 36,
    bufferPages: true,
    info: {
      Title: 'DriveGo Current State Master Audit',
      Author: 'CTO & Principal Systems Architect',
      Subject: 'Architecture, UI/UX, Integration, and Location Fulfillment Reconciliation',
    },
  });

  const outDir = path.join(__dirname, '../../docs/audits');
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }
  const outputPath = path.join(outDir, 'DRIVEGO_CURRENT_STATE_MASTER_AUDIT.pdf');
  const stream = fs.createWriteStream(outputPath);
  doc.pipe(stream);

  const colors = {
    primary: '#0F172A',
    secondary: '#1E293B',
    accent: '#2563EB',
    textDark: '#0F172A',
    textMuted: '#64748B',
    cardBg: '#F8FAFC',
    border: '#CBD5E1',
    green: '#16A34A',
    yellow: '#CA8A04',
    red: '#DC2626',
    blue: '#2563EB',
    cardHeaderBg: '#F1F5F9',
  };

  function drawHeader(title, subtitle) {
    doc.rect(36, 36, 523, 60).fill(colors.primary);
    doc.fillColor('#FFFFFF').fontSize(16).font('Helvetica-Bold').text(title, 48, 48);
    doc.fillColor('#94A3B8').fontSize(9).font('Helvetica').text(subtitle, 48, 70);
  }

  function drawSectionTitle(num, title, y) {
    doc.rect(36, y, 523, 22).fill(colors.secondary);
    doc.fillColor('#FFFFFF').fontSize(10).font('Helvetica-Bold').text(`${num}. ${title.toUpperCase()}`, 44, y + 6);
  }

  // ─── PAGE 1: Executive Summary & Git Baseline ───
  drawHeader(
    'DRIVEGO CURRENT STATE MASTER AUDIT',
    'ARCHITECTURE • UI/UX • INTEGRATION RECONCILIATION • 2 SEPTEMBER 2026'
  );

  let y = 110;
  drawSectionTitle('1', 'Git Baseline & Verification Sign-Off', y);
  y += 28;

  const baselineData = [
    ['Active Branch', 'main', 'Working Tree', 'Clean (No code changes)'],
    ['Current Local HEAD', '3b8fdc338b94396255a839be307bfa0074b367df', 'Sync Status', 'HEAD == origin/main (Synchronized)'],
    ['Phase 29.11 Commits', '3b8fdc3 (Vendor Location Engine)', 'Phase 29.10 Commits', 'bfc814b (Inspection & Handover)'],
    ['Audit Directive', 'NO-CODE-CHANGE / Evidence Only', 'Target Platform', 'Flutter 3.x / NestJS / PostgreSQL / Redis'],
  ];

  for (const row of baselineData) {
    doc.rect(36, y, 120, 18).fill('#F1F5F9').stroke(colors.border);
    doc.fillColor(colors.textDark).fontSize(8).font('Helvetica-Bold').text(row[0], 40, y + 5);

    doc.rect(156, y, 140, 18).fill('#FFFFFF').stroke(colors.border);
    doc.fillColor(colors.textMuted).fontSize(7.5).font('Helvetica').text(row[1], 160, y + 5);

    doc.rect(296, y, 100, 18).fill('#F1F5F9').stroke(colors.border);
    doc.fillColor(colors.textDark).fontSize(8).font('Helvetica-Bold').text(row[2], 300, y + 5);

    doc.rect(396, y, 163, 18).fill('#FFFFFF').stroke(colors.border);
    doc.fillColor(colors.textMuted).fontSize(7.5).font('Helvetica').text(row[3], 400, y + 5);
    y += 18;
  }

  y += 12;
  drawSectionTitle('2', 'Requirements Source of Truth (Six Architecture Docs)', y);
  y += 28;

  const reqDocs = [
    ['01_PRD.docx', 'Product Contract, 7 Handover Modes, Availability & Booking Rules', 'GREEN (Mapped)'],
    ['02_TRD.docx', 'Technical Contract, Thin Controllers, Central Eligibility, Pricing Math', 'YELLOW (Partially Met)'],
    ['03_App_Flow.docx', 'Master Journey: Search -> Eligibility -> Quote -> Snapshot -> Handover', 'YELLOW (String Gap)'],
    ['04_UIUX_Brief.docx', 'DriveGo Design System (DDS) Mobile & Admin Viewport Specs', 'GREEN (DDS Compliant)'],
    ['05_Backend_Schema.docx', '10 Logical Entities: Location, Hours, Exceptions, Policy, Quote, Snapshot', 'BLUE (Schema Overloaded)'],
    ['06_Impl_Plan.docx', '8-Phase Controlled Execution Sequence, Testing Gates & Stop Conditions', 'GREEN (Documented)'],
  ];

  doc.rect(36, y, 110, 16).fill(colors.cardHeaderBg).stroke(colors.border);
  doc.fillColor(colors.textDark).fontSize(8).font('Helvetica-Bold').text('Document', 40, y + 4);
  doc.rect(146, y, 270, 16).fill(colors.cardHeaderBg).stroke(colors.border);
  doc.fillColor(colors.textDark).fontSize(8).font('Helvetica-Bold').text('Scope & Core Contract', 150, y + 4);
  doc.rect(416, y, 143, 16).fill(colors.cardHeaderBg).stroke(colors.border);
  doc.fillColor(colors.textDark).fontSize(8).font('Helvetica-Bold').text('Reconciliation Status', 420, y + 4);
  y += 16;

  for (const r of reqDocs) {
    doc.rect(36, y, 110, 18).fill('#FFFFFF').stroke(colors.border);
    doc.fillColor(colors.accent).fontSize(7.5).font('Helvetica-Bold').text(r[0], 40, y + 5);

    doc.rect(146, y, 270, 18).fill('#FFFFFF').stroke(colors.border);
    doc.fillColor(colors.textDark).fontSize(7).font('Helvetica').text(r[1], 150, y + 5);

    doc.rect(416, y, 143, 18).fill('#FFFFFF').stroke(colors.border);
    const col = r[2].includes('GREEN') ? colors.green : r[2].includes('YELLOW') ? colors.yellow : colors.blue;
    doc.fillColor(col).fontSize(7.5).font('Helvetica-Bold').text(r[2], 420, y + 5);
    y += 18;
  }

  y += 12;
  drawSectionTitle('3', 'Executive Architecture Findings', y);
  y += 28;

  const findings = [
    '• Customer App is fully modernized with DDS tokens across 23 routes; search & booking are operational on live backend.',
    '• Phase 29.11 Vendor Location UI is visually complete (17 native AVD screenshots verified, 33/33 tests passing).',
    '• CRITICAL ARCHITECTURAL GAP: Delivery policies and one-way relocation matrices are stored in transient Redis keys only.',
    '• CONTRACT MISMATCH: Vendor App calls /delivery-policy (404) with PATCH (405) against backend /policy (PUT) with silent catches.',
    '• CUSTOMER INTEGRATION GAP: Customer checkout degrades locations to plain strings and bypasses live /locations/quote math.',
    '• ADMIN CONTROL TOWER: 22 feature pages exist, but layout lacks domain grouping and dedicated Location Review Governance.',
  ];

  doc.rect(36, y, 523, 110).fill(colors.cardBg).stroke(colors.border);
  let fy = y + 8;
  for (const f of findings) {
    doc.fillColor(f.includes('CRITICAL') || f.includes('MISMATCH') ? colors.red : colors.textDark)
      .fontSize(7.5)
      .font(f.includes('CRITICAL') || f.includes('MISMATCH') ? 'Helvetica-Bold' : 'Helvetica')
      .text(f, 44, fy, { width: 505 });
    fy += 16;
  }

  // ─── PAGE 2: Location & Fulfillment Reconciliation Matrix ───
  doc.addPage();
  drawHeader(
    'DRIVEGO CURRENT STATE MASTER AUDIT',
    'SECTION 7: LOCATION & FULFILLMENT RECONCILIATION • 2 SEPTEMBER 2026'
  );

  y = 110;
  drawSectionTitle('7', 'Requirements vs. Actual Implementation Scorecard', y);
  y += 28;

  const entities = [
    ['VendorLocation', 'YELLOW', 'PickupHub model reused; metadata serialized as JSON in operatingHours column.'],
    ['LocationHours', 'YELLOW', 'Stored in JSON blob inside PickupHub.operatingHours; no separate SQL joinable table.'],
    ['LocationException', 'RED', 'Missing completely; no holiday or temporary closure date model in schema.'],
    ['LocationCapability', 'YELLOW', 'allowsPickup/Return/Delivery stored in JSON blob; cannot be indexed for spatial search.'],
    ['ServiceArea', 'GREEN', 'serviceRadiusKm on PickupHub and maxDeliveryRadiusKm enforced in quote calculations.'],
    ['VehicleLocationAssignment', 'GREEN', 'Car.pickupHubId foreign key relation with batch assignment API verified.'],
    ['FulfillmentRule', 'BLUE', 'Stored in Redis cache key (vendor:delivery-policy:<id>) only; no PostgreSQL table.'],
    ['FulfillmentQuote', 'YELLOW', 'Backend math complete in /locations/quote; bypassed by Customer App Checkout.'],
    ['BookingFulfillmentSnapshot', 'YELLOW', 'Flat fields on Booking table; missing oneWayFee snapshot column and hub FKs.'],
    ['LocationAuditEvent', 'GREY', 'Generic AuditLog exists; vendor location CRUD updates currently bypass audit log.'],
  ];

  doc.rect(36, y, 120, 16).fill(colors.cardHeaderBg).stroke(colors.border);
  doc.fillColor(colors.textDark).fontSize(8).font('Helvetica-Bold').text('Entity / Requirement', 40, y + 4);
  doc.rect(156, y, 60, 16).fill(colors.cardHeaderBg).stroke(colors.border);
  doc.fillColor(colors.textDark).fontSize(8).font('Helvetica-Bold').text('Status', 160, y + 4);
  doc.rect(216, y, 343, 16).fill(colors.cardHeaderBg).stroke(colors.border);
  doc.fillColor(colors.textDark).fontSize(8).font('Helvetica-Bold').text('Implementation Reality & Gap Analysis', 220, y + 4);
  y += 16;

  for (const e of entities) {
    doc.rect(36, y, 120, 26).fill('#FFFFFF').stroke(colors.border);
    doc.fillColor(colors.textDark).fontSize(7.5).font('Helvetica-Bold').text(e[0], 40, y + 8);

    doc.rect(156, y, 60, 26).fill('#FFFFFF').stroke(colors.border);
    const c = e[1] === 'GREEN' ? colors.green : e[1] === 'YELLOW' ? colors.yellow : e[1] === 'RED' ? colors.red : e[1] === 'BLUE' ? colors.blue : colors.textMuted;
    doc.fillColor(c).fontSize(8).font('Helvetica-Bold').text(e[1], 165, y + 8);

    doc.rect(216, y, 343, 26).fill('#FFFFFF').stroke(colors.border);
    doc.fillColor(colors.textDark).fontSize(7).font('Helvetica').text(e[2], 220, y + 4, { width: 335 });
    y += 26;
  }

  y += 15;
  drawSectionTitle('8', 'Customer Fulfillment Integration Trace (Home -> Handover)', y);
  y += 28;

  const traceSteps = [
    '1. Customer Home: User selects City and Date Range (Real API).',
    '2. Location Selector: User selects location string from hardcoded list (_cityPopularHubs) -> DATA DEGRADES TO PLAIN STRING.',
    '3. Search & Results: Filters cars by city & dates; passes plain string pickup/drop locations.',
    '4. Vehicle Details: Displays vehicle specifications and mileage package pricing.',
    '5. Checkout Flow (Step 1-5): Computes rental fare; DOES NOT CALL /locations/quote (Zero delivery or one-way fee added).',
    '6. Booking Confirmation: Booking created in DB with flat string pickup/drop location fields.',
    '7. Vendor Handover: Vendor sees plain pickup location string; conducts 4-photo inspection & verifies customer OTP.',
  ];

  doc.rect(36, y, 523, 115).fill(colors.cardBg).stroke(colors.border);
  let ty = y + 8;
  for (const s of traceSteps) {
    doc.fillColor(s.includes('DATA DEGRADES') || s.includes('DOES NOT CALL') ? colors.red : colors.textDark)
      .fontSize(7)
      .font(s.includes('DATA DEGRADES') || s.includes('DOES NOT CALL') ? 'Helvetica-Bold' : 'Helvetica')
      .text(s, 44, ty, { width: 505 });
    ty += 15;
  }

  // ─── PAGE 3: Final CTO Strategic Decision ───
  doc.addPage();
  drawHeader(
    'DRIVEGO CURRENT STATE MASTER AUDIT',
    'SECTION 17: FINAL CTO STRATEGIC DECISION • 2 SEPTEMBER 2026'
  );

  y = 110;
  drawSectionTitle('17', 'Authoritative CTO Answers to the 10 Key Questions', y);
  y += 28;

  const ctoAnswers = [
    ['1. Genuinely Production-Ready', 'Customer Auth, Profile, KYC uploads, Vehicle Search by City/Dates, Mileage Packages, Core Bookings, Vendor Registration, Fleet Management, Fast Add, CSV Bulk Upload, 4-Photo Pre/Post Trip Inspections, Odometer Monotonicity, and OTP Handover Protocols.'],
    ['2. UI-Complete Only', 'Vendor Location Operations Wizard (Phase 29.11) and Admin Operational Map. UI is pristine and fully responsive, but backed by overloaded JSON strings and static fallback data.'],
    ['3. Mock / Fallback Elements', 'Public Location Catalog (in-memory static array), Customer Popular Hubs (_cityPopularHubs), Vendor Initial State (_getStaticMockLocations), Backend Summary Fallbacks (|| 8, || 4), and Wallet Mock Payment Signature.'],
    ['4. Architecturally Incomplete', 'Customer-to-Vendor Fulfillment Integration (Checkout does not request /locations/quote), Delivery Policy Persistence (Redis-only storage), and Admin Location Governance.'],
    ['5. Top 3 Highest Risks', '(1) Redis restart will wipe out vendor delivery configurations; (2) Silent catches in Vendor App conceal 404/405 API failures; (3) Customers are not charged delivery/one-way surcharges.'],
    ['6. Top 3 Highest Value UI Fixes', '(1) Wire dynamic delivery quote calculation into Customer Checkout; (2) Fix URL/method mismatches in Vendor App; (3) Upgrade Admin Operational Map into a Location Governance Control Tower.'],
    ['7. Recommended Next Phase', 'PHASE 29.12: Location & Fulfillment End-to-End Integration & Persistence Hardening (Persist rules to PostgreSQL, align REST contracts, wire Customer Checkout quote, and capture snapshot columns).'],
    ['8. What NOT to Touch Yet', 'Do NOT modify Fleet Management (29.8/29.9), Handover/Inspection (29.10), or Customer Checkout core state machine (29.4/29.5).'],
    ['9. Admin Control Tower Decision', 'Defer Admin Control Tower modernization until immediately after Phase 29.12 to prevent building governance UI on top of transient Redis contracts.'],
    ['10. Location Completion First?', 'YES. Establishing verified, normalized PostgreSQL persistence for locations and delivery quotes is a mandatory prerequisite for Admin Control Tower governance.'],
  ];

  for (const ans of ctoAnswers) {
    doc.rect(36, y, 140, 32).fill(colors.cardHeaderBg).stroke(colors.border);
    doc.fillColor(colors.textDark).fontSize(7.5).font('Helvetica-Bold').text(ans[0], 40, y + 6, { width: 130 });

    doc.rect(176, y, 383, 32).fill('#FFFFFF').stroke(colors.border);
    doc.fillColor(colors.textDark).fontSize(7).font('Helvetica').text(ans[1], 182, y + 4, { width: 370 });
    y += 32;
  }

  y += 15;
  doc.rect(36, y, 523, 24).fill(colors.accent);
  doc.fillColor('#FFFFFF').fontSize(8.5).font('Helvetica-Bold')
    .text('AUDIT CONCLUSION: ARCHITECTURE BASELINE VERIFIED • PROCEED WITH PHASE 29.12', 48, y + 8);

  // Finalize document
  doc.end();
  console.log(`Master Audit PDF successfully generated at: ${outputPath}`);
}

generateMasterAuditPDF();
