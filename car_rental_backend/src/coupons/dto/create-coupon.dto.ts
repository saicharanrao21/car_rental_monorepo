import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsEnum,
  IsNumber,
  IsBoolean,
  IsInt,
  IsDateString,
  Min,
} from 'class-validator';
import { DiscountType, TripType, CarCategory } from '@prisma/client';

export class CreateCouponDto {
  @IsString()
  @IsNotEmpty()
  code: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsEnum(DiscountType)
  discountType: DiscountType;

  @IsNumber()
  @Min(0)
  discountValue: number;

  @IsNumber()
  @IsOptional()
  @Min(0)
  maxDiscountAmount?: number;

  @IsNumber()
  @IsOptional()
  @Min(0)
  minBookingAmount?: number;

  @IsDateString()
  @IsOptional()
  startDate?: string;

  @IsDateString()
  @IsOptional()
  expiresAt?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsInt()
  @IsOptional()
  @Min(1)
  globalUsageLimit?: number;

  @IsInt()
  @IsOptional()
  @Min(1)
  perCustomerLimit?: number;

  @IsBoolean()
  @IsOptional()
  firstBookingOnly?: boolean;

  @IsString()
  @IsOptional()
  city?: string;

  @IsEnum(TripType)
  @IsOptional()
  tripType?: TripType;

  @IsEnum(CarCategory)
  @IsOptional()
  carCategory?: CarCategory;
}
