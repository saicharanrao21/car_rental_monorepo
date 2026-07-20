-- AlterTable
ALTER TABLE "Document" ADD COLUMN     "carId" TEXT;

-- CreateIndex
CREATE INDEX "Document_carId_idx" ON "Document"("carId");

-- AddForeignKey
ALTER TABLE "Document" ADD CONSTRAINT "Document_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;
