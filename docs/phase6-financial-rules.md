# DRIVEGO PHASE 6 FINANCIAL RULES & ACCOUNTING POLICY

---

## 1. Protection Package Pricing & Fare Architecture

1. **Authoritative Server Pricing:**
   - Client applications only submit `protectionPackageId` in the booking draft payload.
   - The backend looks up the active `ProtectionPackage` record matching `(packageId, city)` and extracts `dailyRate`.
   - Protection Fee formula:
     $$\text{protectionFee} = \text{dailyRate} \times \max(1, \text{rentalDays})$$
   - Client-provided amounts in request bodies are completely ignored.

2. **Total Fare Ingestion:**
   $$\text{totalFare} = \text{baseFare} + \text{platformFee} + \text{gstAmount} + \text{deliveryFee} + \text{additionalDriverFee} + \text{protectionFee} - \text{discountAmount}$$

3. **Vendor Payout Isolation:**
   - Protection package fees are retained by the Platform to cover insurance underwriters and risk reserves.
   - Protection fees are **NOT** added to `netToVendor`.
   $$\text{netToVendor} = \text{baseFare} - \text{platformFeeCommission} + \text{deliveryLogisticsFee}$$

---

## 2. Tax (GST) & Invoicing Treatment

1. **GST Applicability:**
   - Platform convenience fee and protection service add-on are taxed at standard 18.00% GST under SAC 998313 (Support and administrative services).
2. **Invoice Breakdown:**
   - Every issued `Invoice` contains explicit line items:
     - `baseFare`
     - `platformFee`
     - `protectionFee`
     - `discountAmount`
     - `gstRate` (18.00%)
     - `gstAmount`
     - `totalFare`
     - `depositAmount` (Escrow — Non-taxable)
3. **Credit Notes on Cancellation:**
   - If a booking is cancelled prior to trip commencement (>24h), the protection fee is 100% refunded and itemized on the generated `CreditNote`.
   - If cancelled within 24h, refund calculation applies platform cancellation tiers.

---

## 3. Deductible & Damage Claim Interaction

1. **Deductible Cap:**
   - Selecting `STANDARD` caps customer maximum liability to the configured `deductibleAmount` (e.g. ₹5,000).
   - Selecting `PREMIUM / ZERO_DEP` caps customer maximum liability to ₹0 for accidental exterior body damages.
2. **Damage Claim Settlement:**
   - When an Admin adjudicates a vendor damage claim on a booking with active protection, customer liability is automatically capped at $\min(\text{claimedAmount}, \text{protectionDeductible})$.
   - Any remaining damage cost above the customer deductible is covered by platform protection reserves.
   - Customer security deposit deduction cannot exceed the customer liability cap.
