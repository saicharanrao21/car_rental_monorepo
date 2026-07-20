import { IsEnum, IsOptional, IsString } from 'class-validator';
import { PaginationDto } from '../../common/pagination.dto';
import { VerificationStatus } from '@prisma/client';

export class VendorsQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsEnum(VerificationStatus, {
    message: 'verificationStatus must be PENDING, VERIFIED, or SUSPENDED',
  })
  verificationStatus?: VerificationStatus;
}
