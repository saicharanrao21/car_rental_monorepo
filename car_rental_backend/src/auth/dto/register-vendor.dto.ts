import { IsEnum, IsInt, IsNotEmpty, IsOptional, IsString, Matches, Min } from 'class-validator';
import { BusinessType } from '@prisma/client';

export class RegisterVendorDto {
  @IsNotEmpty()
  @Matches(/^[6-9]\d{9}$/, {
    message: 'Phone number must be a valid 10-digit Indian mobile number',
  })
  phone: string;

  @IsNotEmpty()
  @IsString()
  businessName: string;

  @IsNotEmpty()
  @IsString()
  ownerName: string;

  @IsNotEmpty()
  @IsString()
  city: string;

  @IsOptional()
  @IsString()
  gstNumber?: string;

  @IsOptional()
  @IsString()
  panNumber?: string;

  @IsOptional()
  @IsString()
  bankDetails?: string;

  @IsNotEmpty()
  @IsEnum(BusinessType, {
    message: 'businessType must be INDIVIDUAL or CONSULTANCY',
  })
  businessType: BusinessType;

  @IsOptional()
  @IsInt()
  @Min(0)
  yearsInOperation?: number;
}
