import {
  IsString,
  IsOptional,
  IsDateString,
  IsEnum,
  IsNumber,
  IsBoolean,
  IsArray,
  Min,
  Max,
} from 'class-validator';
import { Type, Transform } from 'class-transformer';
import { CarCategory, TripType, FuelType } from '@prisma/client';

export enum MarketplaceRankingStrategyType {
  BALANCED = 'BALANCED',
  PRICE_LOW_HIGH = 'PRICE_LOW_HIGH',
  VENDOR_RELIABILITY = 'VENDOR_RELIABILITY',
  PROXIMITY = 'PROXIMITY',
  POPULAR = 'POPULAR',
}

export class MarketplaceSearchQueryDto {
  @IsString()
  pickupLocation: string;

  @IsOptional()
  @IsString()
  pickupBranchId?: string;

  @IsOptional()
  @IsString()
  returnLocation?: string;

  @IsOptional()
  @IsString()
  returnBranchId?: string;

  @IsDateString()
  startDate: string;

  @IsDateString()
  endDate: string;

  @IsOptional()
  @IsEnum(TripType)
  tripType?: TripType = TripType.SELF_DRIVE;

  @IsOptional()
  @IsEnum(CarCategory, { each: true })
  @Transform(({ value }) => (Array.isArray(value) ? value : value ? [value] : undefined))
  vehicleClass?: CarCategory[];

  @IsOptional()
  @IsString()
  transmission?: string; // MANUAL | AUTOMATIC

  @IsOptional()
  @IsString()
  fuelType?: string; // PETROL | DIESEL | ELECTRIC | HYBRID

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  minSeats?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  minLuggage?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  minPrice?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  maxPrice?: number;

  @IsOptional()
  @Transform(({ value }) => (Array.isArray(value) ? value : value ? [value] : undefined))
  vendorIds?: string[];

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(5)
  minRating?: number;

  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  instantConfirmation?: boolean;

  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  deliveryAvailable?: boolean;

  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  airportPickup?: boolean;

  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  isElectric?: boolean;

  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  unlimitedDistance?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(18)
  driverAge?: number;

  @IsOptional()
  @IsArray()
  features?: string[];

  @IsOptional()
  @IsEnum(MarketplaceRankingStrategyType)
  rankingStrategy?: MarketplaceRankingStrategyType = MarketplaceRankingStrategyType.BALANCED;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  customerLatitude?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  customerLongitude?: number;
}
