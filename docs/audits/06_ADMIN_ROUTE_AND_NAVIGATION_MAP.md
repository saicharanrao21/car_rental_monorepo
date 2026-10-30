# DRIVEGO — ADMIN ROUTE AND NAVIGATION ARCHITECTURE MAP

**Document ID:** `DRV-NAV-2026-006`  
**Version:** 1.0.0  
**Effective Date:** October 29, 2026  
**Implementation Codebase:** `apps/admin_panel/lib/core/router/app_router.dart` & `admin_shell.dart`

---

## 1. Executive Summary & 8 Canonical Workspaces

The DriveGo Super Admin Control Tower organizes **40 verified routes** into **8 unified operational workspaces**, eliminating isolated pages and providing a predictable, role-permissioned operating surface.

```
┌────────────────────────────────────────────────────────────────────────┐
│               DRIVEGO SUPER ADMIN CONTROL TOWER WORKSPACES             │
├──────┬────────────────────────────────┬─────────────────┬──────────────┤
│ No.  │ Workspace Name                 │ Primary Purpose │ Role Gates   │
├──────┼────────────────────────────────┼─────────────────┼──────────────┤
│ 1    │ Command Center                 │ Executive KPIs  │ ALL STAFF    │
│ 2    │ Marketplace Operations         │ Fleet & Bookings│ OPS_MGR+     │
│ 3    │ Customers & Safety             │ KYC & Incidents │ SUPPORT+     │
│ 4    │ Finance & Treasury             │ Payouts, Ledger │ FINANCE+     │
│ 5    │ Growth & Engagement            │ Promos & Loyalty│ MARKETING+   │
│ 6    │ Communications & Integrations  │ Fabric, Circuits│ SUPER_ADMIN  │
│ 7    │ People & Governance            │ Staff RBAC, Audit│ COMPLIANCE+ │
│ 8    │ Platform & Engineering         │ Settings, Rules │ SUPER_ADMIN  │
└──────┴────────────────────────────────┴─────────────────┴──────────────┘
```

---

## 2. Complete Route to Workspace Mapping & Permission Gates

| Workspace | Route Path | Page Component | Required Permission | Navigation Badge |
|---|---|---|---|---|
| **1. Command Center** | `/dashboard` | `AdminDashboardPage` | `analytics:read` | — |
| | `/operations-center` | `AdminOperationsCommandCenterPage` | `analytics:read` | `LIVE` |
| | `/revenue` | `RevenueReportsPage` | `analytics:read` | — |
| **2. Marketplace Operations**| `/bookings` | `AdminBookingManagementPage` | `booking:read` | — |
| | `/bookings/:id` | `AdminBookingDetailPage` | `booking:read` | — |
| | `/locations` | `LocationMapTrackingPage` | `location:read` | — |
| | `/fleet` | `AdminFleetManagementPage` | `fleet:read` | — |
| | `/vendors` | `AdminVendorsListPage` | `vendor:read` | — |
| | `/vendors/onboarding` | `VendorOnboardingConsolePage` | `vendor_verification:read` | `APPROVALS` |
| | `/locations/governance` | `LocationGovernancePage` | `location:read` | — |
| | `/supported-cities` | `SupportedCitiesPage` | `location:read` | `CONTROL` |
| **3. Customers & Safety** | `/customers` | `AdminCustomersListPage` | `user:read` | — |
| | `/kyc` | `AdminKycReviewPage` | `kyc:review` | `KYC` |
| | `/support-tickets` | `AdminSupportTicketsPage` | `support:ticket:read` | — |
| | `/disputes` | `AdminDisputesClaimsPage` | `dispute:resolve` | — |
| | `/emergency-dispatch` | `EmergencyDispatchPage` | `emergency:dispatch` | `SOS` |
| **4. Finance & Treasury** | `/payouts` | `AdminPayoutsPage` | `payout:approve` | `PAYOUTS` |
| | `/reconciliation` | `AdminReconciliationPage` | `reconciliation:read` | — |
| | `/commission` | `CommissionSettingsPage` | `commission:manage` | — |
| | `/invoices` | `InvoicesListPage` | `finance:read` | — |
| | `/wallet` | `AdminWalletPage` | `wallet:read` | — |
| | `/protection-packages`| `ProtectionPackagesPage` | `finance:read` | — |
| | `/corporate-accounts` | `CorporateAccountsPage` | `finance:read` | — |
| **5. Growth & Engagement**| `/banners` | `BannersManagementPage` | `banner:manage` | — |
| | `/coupons` | `CouponsManagementPage` | `coupon:manage` | — |
| | `/campaigns` | `AdminMarketingCampaignsPage` | `campaign:manage` | `GROWTH` |
| | `/referrals` | `AdminReferralsPage` | `referral:read` | — |
| | `/loyalty` | `AdminLoyaltyPage` | `loyalty:read` | — |
| **6. Communications & Integrations** | `/communications` | `CommunicationsOverviewPage` | `system:config:read` | `FABRIC` |
| | `/integrations` | `AdminIntegrationsPage` | `system:config:read` | — |
| | `/notification-rules` | `AdminNotificationRulesPage` | `system:config:read` | `RULES` |
| | `/templates` | `CommunicationTemplatesPage` | `system:config:read` | — |
| | `/delivery-logs` | `CommunicationDeliveryLogsPage`| `system:config:read` | — |
| | `/notifications` | `PushNotificationsPage` | `system:config:read` | — |
| | `/whatsapp` | `AdminWhatsAppPage` | `system:config:read` | — |
| | `/automation` | `AdminAutomationOverviewPage` | `system:config:read` | `CRON` |
| **7. People & Governance** | `/staff` | `AdminStaffManagementPage` | `system:config:write` | `RBAC` |
| | `/audit-log` | `AdminAuditLogPage` | `audit:log:read` | — |
| **8. Platform & Engineering** | `/fraud` | `AdminFraudPage` | `fraud:view` | — |
| | `/business-rules` | `BusinessRulesDashboardPage` | `system:config:write` | — |
| | `/settings` | `PlatformSettingsPage` | `system:config:write` | — |

---

## 3. UI/UX Standards & Consistency Matrix

1. **Toolbar Component:** `AdminTableToolbar` implemented across all grid screens providing debounced search, count summary, filter dropdowns, and export triggers.
2. **Pagination:** `AdminPagination` enforcing standard 20/50/100 page sizing with current item span indicators.
3. **Empty States:** Every data table provides dedicated empty state illustrations with clear guidance when records are empty.
4. **Error Handling:** Async riverpod providers provide `error:` view with retry button rather than blank render crashes.
5. **Responsive Layouts:** Desktop multi-column grid collapses cleanly into single column with drawer slide-overs on smaller viewports.

