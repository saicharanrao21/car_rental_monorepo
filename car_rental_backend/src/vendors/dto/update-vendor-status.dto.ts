import { IsEnum, IsNotEmpty } from 'class-validator';
import { VerificationStatus } from '@prisma/client';

export class UpdateVendorStatusDto {
  @IsNotEmpty()
  @IsEnum(VerificationStatus, {
    message: 'status must be PENDING, VERIFIED, or SUSPENDED',
  })
  status: VerificationStatus;
}
