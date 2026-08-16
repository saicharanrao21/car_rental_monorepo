import { IsEnum, IsOptional, IsString } from 'class-validator';
import { KycStatus } from '@prisma/client';

export class ReviewKycDto {
  @IsEnum(KycStatus)
  status!: KycStatus;

  @IsOptional()
  @IsString()
  rejectionReason?: string;
}
