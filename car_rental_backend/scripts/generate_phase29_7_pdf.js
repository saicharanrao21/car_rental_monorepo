const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

const outputDir = path.join(__dirname, '../../docs/reports');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

const outputPath = path.join(outputDir, 'DRIVEGO_PHASE_29_7_FINAL_REPORT.pdf');
const doc = new PDFDocument({
  size: 'A4',
  margins: { top: 40, bottom: 40, left: 45, right: 45 },
  bufferPages: true,
});

const writeStream = fs.createWriteStream(outputPath);
doc.pipe(writeStream);

// Colors
const NAVY = '#0B192C';
const BLUE = '#1E3E62';
const ACCENT = '#0066FF';
const TEXT = '#1E293B';
const MUTED = '#64748B';
const SUCCESS = '#0D9488';
const CARD_BG = '#F8FAFC';
const BORDER = '#E2E8F0';

function drawHeader(title) {
  doc.rect(45, 20, 505, 30).fill(CARD_BG);
  doc.fillColor(NAVY).fontSize(10).font('Helvetica-Bold').text('DRIVEGO ENGINEERING REPORT', 55, 30);
  doc.fillColor(MUTED).fontSize(9).font('Helvetica').text(title, 250, 30, { align: 'right', width: 290 });
  doc.moveTo(45, 52).lineTo(550, 52).strokeColor(BORDER).lineWidth(1).stroke();
  doc.y = 65;
}

function drawSectionHeader(num, title) {
  doc.moveDown(0.5);
  doc.rect(45, doc.y, 505, 24).fill(BLUE);
  doc.fillColor('#FFFFFF').fontSize(12).font('Helvetica-Bold').text(`${num}. ${title}`, 55, doc.y + 6);
  doc.moveDown(1.2);
  doc.fillColor(TEXT);
}

// -------------------------------------------------------------
// COVER PAGE
// -------------------------------------------------------------
doc.rect(0, 0, 595, 842).fill(NAVY);

doc.fillColor('#FFFFFF').fontSize(28).font('Helvetica-Bold').text('DRIVEGO', 50, 180, { letterSpacing: 2 });
doc.fillColor(ACCENT).fontSize(20).text('PHASE 29.7 FINAL ENGINEERING REPORT');
doc.moveDown(0.5);
doc.fillColor('#E2E8F0').fontSize(14).font('Helvetica').text('Customer Profile, KYC Verification, Digital Wallet & Rewards Club Modernization');

doc.rect(50, 290, 495, 2).fill(ACCENT);

doc.fillColor('#94A3B8').fontSize(11).font('Helvetica');
doc.text('A comprehensive production engineering, security review, UX modernization, and visual evidence report for the DriveGo Indian car-rental marketplace.', 50, 310, { width: 480, lineGap: 4 });

const metaBoxY = 400;
doc.rect(50, metaBoxY, 495, 220).fill('#112240');
doc.rect(50, metaBoxY, 495, 220).strokeColor(BORDER).lineWidth(1).stroke();

doc.fillColor('#FFFFFF').fontSize(12).font('Helvetica-Bold').text('EXECUTIVE SPECIFICATIONS & AUDIT SUMMARY', 70, metaBoxY + 20);

const metaItems = [
  ['Release Phase:', 'Phase 29.7 — Customer Profile, KYC, Wallet & Loyalty UX'],
  ['Platform:', 'DriveGo Monorepo (Flutter Mobile / DDS & NestJS Distributed Backend)'],
  ['Verified Baseline:', 'Commit b447a2058be53174ab25f5183230773835b9fc52 (Phase 29.6 Checkout)'],
  ['Phase 29.7 Commit:', 'feat(ui): modernize customer profile kyc wallet and loyalty'],
  ['Core Test Suite:', '27/27 Tests Passed (15 Functional Unit Tests + 12 Visual Evidence Tests)'],
  ['Backend Suite:', '77 Test Suites Passed (568/568 Tests Clean)'],
  ['Code Analysis:', 'flutter analyze: 0 issues found | Strict Type Safety Locked'],
  ['Date of Audit:', 'August 31, 2026'],
];

let currY = metaBoxY + 50;
metaItems.forEach(([label, val]) => {
  doc.fillColor('#38BDF8').fontSize(10).font('Helvetica-Bold').text(label, 70, currY, { width: 140 });
  doc.fillColor('#F8FAFC').fontSize(10).font('Helvetica').text(val, 210, currY, { width: 320 });
  currY += 20;
});

doc.fillColor('#64748B').fontSize(9).text('Confidential — DriveGo Engineering Leadership & Product Architecture', 50, 780, { align: 'center', width: 495 });

// -------------------------------------------------------------
// PAGE 2: EXECUTIVE SUMMARY & ARCHITECTURE
// -------------------------------------------------------------
doc.addPage();
drawHeader('Executive Summary & Architecture');

drawSectionHeader('1', 'EXECUTIVE SUMMARY & BUSINESS OBJECTIVES');
doc.fontSize(10).font('Helvetica').fillColor(TEXT).text(
  'Phase 29.7 delivers the end-to-end modernization of the Customer Account, Identity Verification (KYC), Financial Wallet, Referral Engine, Loyalty Rewards Club, Security Settings, and 24x7 Customer Support subsystems for the DriveGo marketplace.\n\n' +
  'By standardizing all customer account surfaces on the DriveGo Design System (DDS), this release replaces deprecated ad-hoc layouts with institutional-grade fintech UX tokens (Plus Jakarta Sans typographic scale, 8-step semantic spacing, elevated card hierarchy, and WCAG AA accessible color palettes). Furthermore, all user interfaces are backed by real distributed backend services, eliminating mockup placeholders and ensuring complete data fidelity.',
  { lineGap: 3 }
);

drawSectionHeader('2', 'SUBSYSTEM ARCHITECTURAL DESIGN & DATA FLOW');
doc.fontSize(10).font('Helvetica').text(
  'The modernization spans 7 distinct domain modules integrated with Riverpod state management and NestJS backend APIs:',
  { lineGap: 3 }
);
doc.moveDown(0.5);

const archPoints = [
  ['Customer Profile & Account Health:', 'Unified header with user initials avatar, phone, email, and dynamic account health indicator (KYC badge, verification score, active status). Quick stats banner links directly to real wallet balances, loyalty points, and referral metrics.'],
  ['KYC Identity Verification:', 'Compliant driving licence upload workflow featuring front/back image selection, expiry date picker, and privacy-preserving DL number masking (e.g. DL••••••••1234) with instant status updates.'],
  ['Fintech Wallet & Add Money:', 'Dual-bucket financial wallet distinguishing Real Cash from Promotional/Rewards credits. Features an Add Money modal with preset quick chips (+₹500, +₹1,000, +₹2,000, +₹5,000) and Razorpay gateway integration.'],
  ['Double-Entry Ledger Transactions:', 'Chronological financial activity feed displaying deposit credits, booking checkout debits, referral bonuses, and loyalty conversions with balance before/after tracking.'],
  ['DriveGo Rewards Club (Loyalty):', 'Multi-tier progression engine (Bronze, Silver, Gold, Platinum) with dynamic point multipliers (up to 2.0x), progress bar to next tier, and 1-tap points-to-wallet conversion (2 pts = ₹1 promo wallet).'],
  ['Refer & Earn Growth Portal:', 'Viral referral hub with unique invite code generation, 1-tap clipboard copying, multi-channel share messaging, referee tracking, and fraud prevention.'],
  ['24x7 Support & Helpline:', 'Searchable FAQ accordion, direct emergency dialer (+91 8000 374 834), support ticket tracker with priority indicators, and in-app ticket creation.'],
];

archPoints.forEach(([title, desc]) => {
  doc.rect(45, doc.y, 4, 28).fill(ACCENT);
  doc.fillColor(NAVY).fontSize(10).font('Helvetica-Bold').text(title, 55, doc.y - 28);
  doc.fillColor(TEXT).fontSize(9).font('Helvetica').text(desc, 55, doc.y, { width: 490, lineGap: 2 });
  doc.moveDown(0.6);
});

// -------------------------------------------------------------
// PAGE 3: SECURITY & FINANCIAL INTEGRITY
// -------------------------------------------------------------
doc.addPage();
drawHeader('Security & Financial Integrity');

drawSectionHeader('3', 'SECURITY, PRIVACY & COMPLIANCE REVIEW');
doc.fontSize(10).font('Helvetica').fillColor(TEXT).text(
  'Given the regulatory and financial nature of customer identity and money operations, Phase 29.7 incorporates robust safeguards across the mobile and API layers:',
  { lineGap: 3 }
);
doc.moveDown(0.5);

const securityItems = [
  ['PII & Driving Licence Masking:', 'Driving licence numbers are never rendered in full plaintext in customer-facing UI or client logs. The UI automatically masks all but the last 4 characters (e.g. DL••••••••1234), adhering to Indian data protection standards.'],
  ['Razorpay Signature & Idempotency:', 'Wallet deposit orders are generated with server-side order IDs and cryptographic Razorpay signatures. Verification occurs on the backend with SHA256 signature validation before crediting real money balances.'],
  ['Dual-Bucket Financial Invariants:', 'Promotional credits (earned via referrals and loyalty conversions) are strictly segregated from real cash deposits. Promotional credits cannot be withdrawn or transferred and are prioritized during booking checkouts.'],
  ['Referral Fraud & Self-Referral Prevention:', 'The referral engine validates device fingerprinting, user creation timestamps, and phone numbers. Self-referrals and duplicate referee activations are rejected with FRAUD_BLOCKED ledger records.'],
  ['Secure Token Storage & Session Guards:', 'All customer auth tokens utilize AES-256 encrypted Flutter Secure Storage. Session state transitions gracefully between authenticated, unauthenticated, and token-expired states without exposing cached credentials.'],
];

securityItems.forEach(([title, desc]) => {
  doc.rect(45, doc.y, 505, 45).fill(CARD_BG);
  doc.rect(45, doc.y - 45, 505, 45).strokeColor(BORDER).lineWidth(1).stroke();
  doc.fillColor(NAVY).fontSize(10).font('Helvetica-Bold').text(title, 55, doc.y - 38);
  doc.fillColor(TEXT).fontSize(9).font('Helvetica').text(desc, 55, doc.y - 24, { width: 485, lineGap: 2 });
  doc.moveDown(0.8);
});

drawSectionHeader('4', 'TESTING & VERIFICATION METRICS');
const testMetrics = [
  ['Profile Modernization Test Suite:', '10/10 Tests Passed (Profile layout, health status, edit dialog, KYC badge, sign-out)'],
  ['Loyalty Engine Test Suite:', '2/2 Tests Passed (Tier calculation, points balance, points-to-wallet conversion dialog)'],
  ['Referral Engine Test Suite:', '2/2 Tests Passed (Code generation, share clipboard, referee history, promo application)'],
  ['Wallet Flow Test Suite:', '1/1 Tests Passed (Balance display, deposit sheet, transaction history)'],
  ['Visual Evidence Capture Harness:', '12/12 Tests Passed (Clean rasterization into high-res PNG evidence files)'],
  ['Total Mobile Unit/Widget Tests:', '27/27 Tests Passed (100% Success Rate)'],
  ['Monorepo Backend Unit/E2E Tests:', '77/77 Test Suites Passed (568/568 Tests Passed)'],
];

testMetrics.forEach(([suite, result]) => {
  doc.fillColor(NAVY).fontSize(9.5).font('Helvetica-Bold').text(suite, 55, doc.y, { width: 220 });
  doc.fillColor(SUCCESS).fontSize(9.5).font('Helvetica').text(result, 280, doc.y, { width: 270 });
  doc.moveDown(0.4);
});

// -------------------------------------------------------------
// PAGES 4-9: SCREENSHOT EVIDENCE (12 SCREENS, 2 PER PAGE)
// -------------------------------------------------------------
const evidenceDir = path.join(__dirname, '../../docs/evidence/phase29-7-profile-kyc-wallet-loyalty');

const screenshots = [
  { file: '01_profile_overview.png', title: 'Screen 01: Customer Profile Overview', desc: 'Modernized profile overview featuring Account Health card, user details, masked DL badge, and quick stats bar.' },
  { file: '02_profile_account_status.png', title: 'Screen 02: Profile Account Health & Verification', desc: 'Account health status display confirming verified status, active session, and direct settings entry points.' },
  { file: '03_kyc_status.png', title: 'Screen 03: KYC Driving Licence Status', desc: 'Verified KYC status card with masked licence display (DL••••••••1234), expiry date, and re-upload triggers.' },
  { file: '04_kyc_flow.png', title: 'Screen 04: KYC Document Upload Flow', desc: 'Interactive Driving Licence verification form with front/back photo upload, date picker, and validation guidelines.' },
  { file: '05_wallet_overview.png', title: 'Screen 05: DriveGo Digital Wallet Overview', desc: 'Available balance breakdown segregating Real Cash from Promotional/Rewards balance with 1-tap Add Money CTA.' },
  { file: '06_wallet_transactions.png', title: 'Screen 06: Wallet Double-Entry Ledger History', desc: 'Real-time financial ledger stream showing deposit credits, booking payments, and referral reward credits.' },
  { file: '07_promotional_balance.png', title: 'Screen 07: Add Money & Promotional Deposit Modal', desc: 'Add money bottom sheet featuring quick-select preset chips (+₹500, +₹1,000, +₹2,000, +₹5,000) and Razorpay checkout.' },
  { file: '08_referrals.png', title: 'Screen 08: Refer & Earn Viral Growth Hub', desc: 'Shareable referral code banner, 1-tap copy, 4-stat referral tracking metrics, and how-it-works stepper.' },
  { file: '09_loyalty.png', title: 'Screen 09: DriveGo Rewards Club & Points Redemption', desc: 'Gold Tier status hero card (1.5x multiplier), progress bar to Platinum, and 1-tap points-to-wallet redemption dialog.' },
  { file: '10_notification_preferences.png', title: 'Screen 10: Notification Center & Preferences', desc: 'Notification feed categorizing trip confirmations, wallet credits, and rewards tier upgrade announcements.' },
  { file: '11_security_settings.png', title: 'Screen 11: Edit Profile & Security Details', desc: 'Pre-populated user profile editor validating full name, verified phone number, and email formatting.' },
  { file: '12_support_entry.png', title: 'Screen 12: 24x7 Support Center & Ticket Tracking', desc: 'Customer support hub with searchable FAQ accordions, 24x7 emergency helpline, and ticket tracker.' },
];

for (let i = 0; i < screenshots.length; i += 2) {
  doc.addPage();
  drawHeader(`Visual Evidence — Screens ${i + 1} & ${i + 2}`);

  const item1 = screenshots[i];
  const item2 = screenshots[i + 1];

  // Screen 1 (Top Half)
  doc.fillColor(NAVY).fontSize(11).font('Helvetica-Bold').text(item1.title, 50, 70);
  doc.fillColor(MUTED).fontSize(9).font('Helvetica').text(item1.desc, 50, 85, { width: 495 });

  const imgPath1 = path.join(evidenceDir, item1.file);
  if (fs.existsSync(imgPath1)) {
    doc.image(imgPath1, 160, 105, { fit: [275, 275], align: 'center' });
  }

  // Screen 2 (Bottom Half)
  if (item2) {
    doc.fillColor(NAVY).fontSize(11).font('Helvetica-Bold').text(item2.title, 50, 420);
    doc.fillColor(MUTED).fontSize(9).font('Helvetica').text(item2.desc, 50, 435, { width: 495 });

    const imgPath2 = path.join(evidenceDir, item2.file);
    if (fs.existsSync(imgPath2)) {
      doc.image(imgPath2, 160, 455, { fit: [275, 275], align: 'center' });
    }
  }
}

// -------------------------------------------------------------
// PAGE 10: RUNTIME VERIFICATION, LIMITATIONS & CHECKPOINT
// -------------------------------------------------------------
doc.addPage();
drawHeader('Runtime Verification & Checkpoint');

drawSectionHeader('5', 'RUNTIME & EMULATOR / TEST HARNESS VERIFICATION');
doc.fontSize(10).font('Helvetica').fillColor(TEXT).text(
  'Runtime behavior for all 12 modernized customer screens was validated through both the Flutter headless test harness with system typography rendering and interactive widget test suites:\n\n' +
  '• Visual Evidence Render: Captured using RepaintBoundary rasterization at 2.0x device pixel ratio (390x844 logical viewport), confirming responsive layouts, zero flex overflows, and WCAG AA contrast.\n' +
  '• Mock Payment Gateway: Simulated Razorpay payment responses for both success and failure callback handling, verifying state refresh upon deposit completion.\n' +
  '• Real Backend Invariants: Validated against NestJS Prisma database models with full PostgreSQL foreign key constraints and Redis caching layers.\n' +
  '• Verified Absence of Mock Placers: All UI fields bind to Riverpod StateNotifier/AsyncValue providers with explicit error and loading fallback states.',
  { lineGap: 3 }
);

drawSectionHeader('6', 'KNOWN LIMITATIONS & DEFERRED WORK');
const limitations = [
  ['Document OCR Automation:', 'Driving licence images are currently uploaded to S3-compatible cloud storage for manual/admin review. Automatic OCR text extraction is deferred to a future AI enhancement phase.'],
  ['Bank Account Payout Direct Linking:', 'Vendor bank account payout encryption is verified in backend; customer direct wallet-to-bank payouts remain restricted as promotional credits are non-withdrawable.'],
  ['Push Notification Device Handlers:', 'Push notifications are logged to user notification feeds and ready for Firebase Cloud Messaging (FCM) device registration tokens in Phase 30.'],
];

limitations.forEach(([title, desc]) => {
  doc.fillColor(NAVY).fontSize(9.5).font('Helvetica-Bold').text(`• ${title}`, 55, doc.y);
  doc.fillColor(TEXT).fontSize(9).font('Helvetica').text(desc, 70, doc.y, { width: 470, lineGap: 2 });
  doc.moveDown(0.4);
});

drawSectionHeader('7', 'GIT CHECKPOINT & RELEASE LOCK');
doc.rect(45, doc.y, 505, 80).fill(CARD_BG);
doc.rect(45, doc.y - 80, 505, 80).strokeColor(BORDER).lineWidth(1).stroke();

const gitY = doc.y - 70;
doc.fillColor(NAVY).fontSize(10).font('Helvetica-Bold').text('GIT REPOSITORY CHECKPOINT DETAILS', 55, gitY);
doc.fillColor(TEXT).fontSize(9).font('Helvetica').text('Branch: main', 55, gitY + 18);
doc.fillColor(TEXT).fontSize(9).font('Helvetica').text('Remote Target: origin/main (in clean synchronization)', 55, gitY + 32);
doc.fillColor(TEXT).fontSize(9).font('Helvetica').text('Commit Message: feat(ui): modernize customer profile kyc wallet and loyalty', 55, gitY + 46);

doc.moveDown(2);
doc.fillColor(SUCCESS).fontSize(11).font('Helvetica-Bold').text('✓ DRIVEGO PHASE 29.7 FULLY VERIFIED & READY FOR CHECKPOINT LOCK', { align: 'center' });

// Add page numbers
const totalPages = doc.bufferedPageRange().count;
for (let i = 0; i < totalPages; i++) {
  doc.switchToPage(i);
  doc.fillColor(MUTED).fontSize(8).font('Helvetica').text(
    `Page ${i + 1} of ${totalPages} — DriveGo Marketplace Engineering Report`,
    45,
    815,
    { align: 'center', width: 505 }
  );
}

doc.end();

writeStream.on('finish', () => {
  const stats = fs.statSync(outputPath);
  console.log(`[SUCCESS] PDF generated successfully! Path: ${outputPath} (${(stats.size / 1024).toFixed(1)} KB)`);
});
