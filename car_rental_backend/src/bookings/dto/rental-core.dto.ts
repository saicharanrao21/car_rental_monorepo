import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsEnum,
  IsDateString,
  IsNumber,
  IsBoolean,
  Min,
  Max,
} from 'class-validator';
import { CarCategory, FuelType, PricingRuleScope, TripType } from '@prisma/client';

export class SearchClassAvailabilityDto {
  @IsOptional()
  @IsString()
  vendorId?: string;

  @IsOptional()
  @IsString()
  branchId?: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsEnum(CarCategory)
  vehicleClass?: CarCategory;

  @IsDateString()
  @IsNotEmpty()
  startDate: string;

  @IsDateString()
  @IsNotEmpty()
  endDate: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  minCapacity?: number;

  @IsOptional()
  @IsEnum(FuelType)
  fuelType?: FuelType;

  @IsOptional()
  @IsNumber()
  @Min(0)
  turnaroundBufferMinutes?: number;
}

export class CalculateRentalPricingDto {
  @IsString()
  @IsNotEmpty()
  vendorId: string;

  @IsOptional()
  @IsString()
  branchId?: string;

  @IsOptional()
  @IsString()
  returnBranchId?: string;

  @IsEnum(CarCategory)
  vehicleClass: CarCategory;

  @IsOptional()
  @IsString()
  carId?: string;

  @IsDateString()
  @IsNotEmpty()
  startDate: string;

  @IsDateString()
  @IsNotEmpty()
  endDate: string;

  @IsEnum(TripType)
  tripType: TripType;

  @IsOptional()
  @IsNumber()
  distanceKm?: number;

  @IsOptional()
  @IsString()
  couponCode?: string;

  @IsOptional()
  @IsNumber()
  couponDiscountAmount?: number;

  @IsOptional()
  @IsNumber()
  pickupFee?: number;

  @IsOptional()
  @IsNumber()
  returnFee?: number;
}

export class AllocateVehicleDto {
  @IsOptional()
  @IsString()
  targetCarId?: string;

  @IsString()
  @IsNotEmpty()
  strategy: 'EXACT_VEHICLE' | 'SAME_CLASS' | 'AUTOMATIC' | 'BRANCH_BASED' | 'NEAREST_SUITABLE' | 'MANUAL_OVERRIDE';

  @IsOptional()
  @IsString()
  reason?: string;

  @IsOptional()
  @IsBoolean()
  allowUpgrade?: boolean;
}

export class ExecutePickupDto {
  @IsString()
  @IsNotEmpty()
  bookingId: string;

  @IsNumber()
  @Min(0)
  odometerReading: number;

  @IsNumber()
  @Min(0)
  @Max(100)
  fuelPercent: number;

  @IsOptional()
  @IsString()
  handoverOtpCode?: string;

  @IsOptional()
  inspectionPhotos?: string[];

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsBoolean()
  skipOtpForAdmin?: boolean;
}

export class ExecuteReturnDto {
  @IsString()
  @IsNotEmpty()
  bookingId: string;

  @IsNumber()
  @Min(0)
  odometerReading: number;

  @IsNumber()
  @Min(0)
  @Max(100)
  fuelPercent: number;

  @IsOptional()
  @IsString()
  handoverOtpCode?: string;

  @IsOptional()
  inspectionPhotos?: string[];

  @IsOptional()
  @IsString()
  newDamagesNotes?: string;

  @IsOptional()
  @IsNumber()
  damageEstimatedCost?: number;

  @IsOptional()
  @IsBoolean()
  skipOtpForAdmin?: boolean;
}

export class CreateRentalPricingRuleDto {
  @IsEnum(PricingRuleScope)
  scope: PricingRuleScope;

  @IsString()
  @IsNotEmpty()
  name: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  vendorId?: string;

  @IsOptional()
  @IsString()
  branchId?: string;

  @IsOptional()
  @IsEnum(CarCategory)
  vehicleClass?: CarCategory;

  @IsOptional()
  @IsString()
  carId?: string;

  @IsOptional()
  @IsNumber()
  hourlyRateMultiplier?: number;

  @IsOptional()
  @IsNumber()
  dailyRate?: number;

  @IsOptional()
  @IsNumber()
  weeklyDiscountPct?: number;

  @IsOptional()
  @IsNumber()
  monthlyDiscountPct?: number;

  @IsOptional()
  @IsNumber()
  weekendMultiplier?: number;

  @IsOptional()
  @IsNumber()
  peakSeasonMultiplier?: number;

  @IsOptional()
  @IsNumber()
  holidayMultiplier?: number;

  @IsOptional()
  @IsNumber()
  extraKmRate?: number;

  @IsOptional()
  @IsNumber()
  lateReturnHourlyFee?: number;

  @IsOptional()
  @IsNumber()
  securityDepositAmount?: number;

  @IsOptional()
  @IsNumber()
  convenienceFee?: number;

  @IsOptional()
  @IsNumber()
  oneWayBaseFee?: number;

  @IsOptional()
  @IsNumber()
  priority?: number;

  @IsOptional()
  @IsDateString()
  effectiveFrom?: string;

  @IsOptional()
  @IsDateString()
  effectiveTo?: string;
}
