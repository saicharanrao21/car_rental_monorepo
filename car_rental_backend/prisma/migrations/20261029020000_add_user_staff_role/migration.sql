-- Non-destructive migration to add granular staff role delegation to User
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "staffRole" TEXT;

-- Create index for high-performance role-based staff queries
CREATE INDEX IF NOT EXISTS "User_staffRole_idx" ON "User"("staffRole");
