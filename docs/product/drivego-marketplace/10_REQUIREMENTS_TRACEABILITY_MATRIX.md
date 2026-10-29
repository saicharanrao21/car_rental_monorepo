# DriveGo Self-Drive Mobility Marketplace — Requirements Traceability Matrix (RTM)

**Document Reference:** `RTM-MKT-10`  
**Version:** 2.0.0-PROD  
**Author:** DriveGo QA Lead & System Architect  
**Scope:** Bidirectional Traceability: PRD -> TRD -> Frontend -> Backend -> Database -> Automated Tests  
**Status:** Approved for Implementation

---

## 1. Bidirectional Requirements Traceability Matrix

| Req ID | Requirement Description | TRD Component | Frontend Component | Backend Controller & Service | Prisma Model & Field | Test Case | Status |
|:---|:---|:---|:---|:---|:---|:---|:---:|
| **REQ-DEP-01** | One Authoritative Admin Deposit Policy | `TRD §3.2` | `apps/admin_panel/.../vendor_onboarding_console_page.dart` | `VendorSecurityDepositService.updatePolicy()` | `VendorDepositPolicy.amount` | `TC-DEP-01` | `COMPLETE_AND_VERIFIED` |
| **REQ-DEP-02** | No Arbitrary Silent Fallback Amount | `TRD §3.2` | `apps/vendor_app/.../pending_approval_page.dart` | `VendorSecurityDepositService.getActivePolicy()` | `VendorDepositPolicy.isActive` | `TC-DEP-02` | `COMPLETE_AND_VERIFIED` |
| **REQ-DEP-03** | Server-Authoritative Razorpay Order & HMAC Verification | `TRD §3.2` | `apps/vendor_app/.../pending_approval_page.dart` | `VendorSecurityDepositService.verifyDepositPayment()` | `VendorSecurityDeposit.providerPaymentId` | `TC-DEP-03` | `COMPLETE_AND_VERIFIED` |
| **REQ-DEP-04** | Administrative Exemption Waiver | `TRD §3.2` | `apps/admin_panel/.../vendor_onboarding_console_page.dart` | `VendorSecurityDepositService.grantExemption()` | `VendorSecurityDeposit.isExempted` | `TC-DEP-04` | `COMPLETE_AND_VERIFIED` |
| **REQ-PHT-01** | Elimination of Stock Photos (`samplePhotos`) | `TRD §3.1` | `apps/vendor_app/.../add_edit_car_page.dart` | `CarService.createCar()` | `Car.photos` | `TC-PHT-01` | `COMPLETE_AND_VERIFIED` |
| **REQ-PHT-02** | Native Camera/Gallery Picker with Presigned Direct Upload | `TRD §3.1` | `apps/vendor_app/.../add_edit_car_page.dart` | `UploadsController.presign()` | `UploadService` (`car-photo`) | `TC-PHT-02` | `COMPLETE_AND_VERIFIED` |
| **REQ-PUB-01** | Bounded Timeout & Non-Stuck Publication Spinner | `TRD §2.1` | `apps/vendor_app/.../add_edit_car_page.dart` | `VendorFleetController.createVehicle()` | `Car.operationalStatus` | `TC-PUB-01` | `COMPLETE_AND_VERIFIED` |
| **REQ-PUB-02** | Explicit Publication Lifecycle Transitions | `TRD §2.1` | `apps/vendor_app/.../fleet_car_detail_page.dart` | `VendorFleetService.submitForVerification()` | `Car.verificationStatus` | `TC-PUB-02` | `COMPLETE_AND_VERIFIED` |
| **REQ-LOC-01** | Elimination of Fictional Preset Hubs | `TRD §1` | `apps/vendor_app/.../add_edit_car_page.dart` | `LocationsController.getPickupHubs()` | `PickupHub.name` | `TC-LOC-01` | `COMPLETE_AND_VERIFIED` |
| **REQ-LOC-02** | Vendor-Managed Genuine Operating Yards in Supported Cities | `TRD §1` | `apps/vendor_app/.../add_edit_car_page.dart` | `LocationsController.createHub()` | `PickupHub.vendorId` | `TC-LOC-02` | `COMPLETE_AND_VERIFIED` |
| **REQ-LOC-03** | Vehicle-to-Operating Yard Association (`pickupHubId`) | `TRD §1` | `apps/vendor_app/.../add_edit_car_page.dart` | `VendorFleetService.createVehicle()` | `Car.pickupHubId` | `TC-LOC-03` | `COMPLETE_AND_VERIFIED` |
| **REQ-SOD-01** | Segregation of Duties: Dual Authorization on Payouts > ₹50,000 | `TRD §4` | `apps/admin_panel/.../admin_payouts_page.dart` | `PayoutsService.executePayout()` | `VendorPayout.approverId` | `TC-SOD-01` | `COMPLETE_AND_VERIFIED` |
| **REQ-RBAC-01**| Granular 7 Staff Roles with Read-Only Analyst Assertion | `TRD §1` | `apps/admin_panel/.../admin_staff_management_page.dart` | `AdminStaffService` & `PermissionsGuard` | `User.staffRole` | `admin-staff.spec`| `COMPLETE_AND_VERIFIED` |
| **REQ-DPDP-01**| Customer Right to Erasure with 7-Year Ledger Retention | `TRD §4` | `apps/admin_panel/.../customer_management_page.dart` | `UsersService.anonymizeUser()` | `User.isSuspended` | `TC-DPDP-01` | `COMPLETE_AND_VERIFIED` |
