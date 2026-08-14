-- CreateIndex: Partial Unique Index to enforce exactly ONE active damage claim per booking at database level
CREATE UNIQUE INDEX "unique_active_damage_claim_per_booking" ON "DamageClaim"("bookingId") 
WHERE "status" IN ('SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'PARTIALLY_APPROVED');
