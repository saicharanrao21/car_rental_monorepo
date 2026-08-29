import {
  IsEnum,
  IsISO8601,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';
import { DiscountType, CarCategory } from '@prisma/client';

export class CreatePromotionalCampaignDto {
  @IsNotEmpty()
  @IsString()
  code: string;

  @IsNotEmpty()
  @IsString()
  name: string;

  @IsOptional()
  @IsString()
  type?: string; // FIRST_BOOKING, WEEKEND, FESTIVAL, CITY_LAUNCH, VENDOR_PROMOTION

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsEnum(CarCategory)
  carCategory?: CarCategory;

  @IsOptional()
  @IsEnum(DiscountType)
  discountType?: DiscountType;

  @IsNotEmpty()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  discountValue: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  maxDiscountAmount?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  minBookingAmount?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  budget?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  maxRedemptions?: number;

  @IsOptional()
  @IsISO8601()
  startDate?: string;

  @IsOptional()
  @IsISO8601()
  endDate?: string;
}
