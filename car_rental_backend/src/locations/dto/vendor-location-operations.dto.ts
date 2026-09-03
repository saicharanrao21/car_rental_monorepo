import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsNumber,
  IsBoolean,
  IsEnum,
  Min,
  Max,
  IsArray,
} from 'class-validator';
import { Type } from 'class-transformer';

export enum VendorLocationTypeEnum {
  VENDOR_YARD = 'VENDOR_YARD',
  BRANCH = 'BRANCH',
  OFFICE = 'OFFICE',
  AIRPORT = 'AIRPORT',
  RAILWAY_STATION = 'RAILWAY_STATION',
  BUS_TERMINAL = 'BUS_TERMINAL',
  PUBLIC_POINT = 'PUBLIC_POINT',
  HOTEL = 'HOTEL',
  CUSTOM_POINT = 'CUSTOM_POINT',
}

export enum VendorLocationStatusEnum {
  ACTIVE = 'ACTIVE',
  INACTIVE = 'INACTIVE',
  TEMPORARILY_CLOSED = 'TEMPORARILY_CLOSED',
  PENDING_APPROVAL = 'PENDING_APPROVAL',
  SUSPENDED = 'SUSPENDED',
}

export enum DeliveryPricingModelEnum {
  FREE = 'FREE',
  FIXED = 'FIXED',
  DISTANCE_BASED = 'DISTANCE_BASED',
}

export class CreateVendorLocationDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsEnum(VendorLocationTypeEnum)
  @IsOptional()
  type?: VendorLocationTypeEnum = VendorLocationTypeEnum.VENDOR_YARD;

  @IsString()
  @IsNotEmpty()
  address: string;

  @IsString()
  @IsOptional()
  locality?: string;

  @IsString()
  @IsNotEmpty()
  city: string;

  @IsString()
  @IsOptional()
  state?: string;

  @IsString()
  @IsOptional()
  pincode?: string;

  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  latitude: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  longitude: number;

  @IsString()
  @IsOptional()
  contactPerson?: string;

  @IsString()
  @IsOptional()
  contactPhone?: string;

  @IsBoolean()
  @IsOptional()
  allowsPickup?: boolean = true;

  @IsBoolean()
  @IsOptional()
  allowsReturn?: boolean = true;

  @IsBoolean()
  @IsOptional()
  allowsDelivery?: boolean = false;

  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  pickupFee?: number = 0;

  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  returnFee?: number = 0;

  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  oneWayFee?: number = 0;

  @IsString()
  @IsOptional()
  openingTime?: string = '08:00';

  @IsString()
  @IsOptional()
  closingTime?: string = '22:00';

  @IsBoolean()
  @IsOptional()
  is24x7?: boolean = false;

  @IsNumber()
  @Min(1)
  @Max(150)
  @IsOptional()
  @Type(() => Number)
  serviceRadiusKm?: number = 25.0;

  @IsArray()
  @IsOptional()
  assignedCarIds?: string[] = [];
}

export class UpdateVendorLocationDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsEnum(VendorLocationTypeEnum)
  @IsOptional()
  type?: VendorLocationTypeEnum;

  @IsString()
  @IsOptional()
  address?: string;

  @IsString()
  @IsOptional()
  locality?: string;

  @IsString()
  @IsOptional()
  city?: string;

  @IsString()
  @IsOptional()
  state?: string;

  @IsString()
  @IsOptional()
  pincode?: string;

  @IsNumber()
  @Min(-90)
  @Max(90)
  @IsOptional()
  @Type(() => Number)
  latitude?: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @IsOptional()
  @Type(() => Number)
  longitude?: number;

  @IsString()
  @IsOptional()
  contactPerson?: string;

  @IsString()
  @IsOptional()
  contactPhone?: string;

  @IsEnum(VendorLocationStatusEnum)
  @IsOptional()
  status?: VendorLocationStatusEnum;

  @IsBoolean()
  @IsOptional()
  allowsPickup?: boolean;

  @IsBoolean()
  @IsOptional()
  allowsReturn?: boolean;

  @IsBoolean()
  @IsOptional()
  allowsDelivery?: boolean;

  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  pickupFee?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  returnFee?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  oneWayFee?: number;

  @IsString()
  @IsOptional()
  openingTime?: string;

  @IsString()
  @IsOptional()
  closingTime?: string;

  @IsBoolean()
  @IsOptional()
  is24x7?: boolean;

  @IsNumber()
  @Min(1)
  @Max(150)
  @IsOptional()
  @Type(() => Number)
  serviceRadiusKm?: number;

  @IsArray()
  @IsOptional()
  assignedCarIds?: string[];
}

export class UpdateVendorDeliveryPolicyDto {
  @IsBoolean()
  @IsOptional()
  deliveryEnabled?: boolean;

  @IsNumber()
  @Min(1)
  @Max(100)
  @IsOptional()
  @Type(() => Number)
  maxDeliveryRadiusKm?: number;

  @IsEnum(DeliveryPricingModelEnum)
  @IsOptional()
  pricingModel?: DeliveryPricingModelEnum;

  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  baseDeliveryFee?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  perKmDeliveryFee?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  freeDeliveryWithinKm?: number;
}

export class CalculateDeliveryQuoteDto {
  @IsString()
  @IsNotEmpty()
  vendorId: string;

  @IsNumber()
  @Min(-90)
  @Max(90)
  @IsOptional()
  @Type(() => Number)
  customerLatitude?: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @IsOptional()
  @Type(() => Number)
  customerLongitude?: number;

  @IsString()
  @IsOptional()
  pickupLocationId?: string;

  @IsString()
  @IsOptional()
  returnLocationId?: string;

  @IsString()
  @IsOptional()
  carId?: string;

  @IsString()
  @IsOptional()
  deliveryAddress?: string;

  @IsString()
  @IsOptional()
  pickupAddress?: string;
}

export enum LocationExceptionTypeEnum {
  HOLIDAY = 'HOLIDAY',
  TEMPORARY_CLOSURE = 'TEMPORARY_CLOSURE',
  EMERGENCY_CLOSURE = 'EMERGENCY_CLOSURE',
  CUSTOM_HOURS = 'CUSTOM_HOURS',
}

export class CreateLocationExceptionDto {
  @IsString()
  @IsNotEmpty()
  date: string;

  @IsEnum(LocationExceptionTypeEnum)
  @IsOptional()
  exceptionType?: LocationExceptionTypeEnum = LocationExceptionTypeEnum.HOLIDAY;

  @IsBoolean()
  @IsOptional()
  isClosed?: boolean = true;

  @IsString()
  @IsOptional()
  customOpeningTime?: string;

  @IsString()
  @IsOptional()
  customClosingTime?: string;

  @IsString()
  @IsOptional()
  reason?: string;
}

export class LocationMatrixItemDto {
  @IsString()
  @IsNotEmpty()
  pickupLocationId: string;

  @IsString()
  @IsNotEmpty()
  returnLocationId: string;

  @IsBoolean()
  @IsNotEmpty()
  isSupported: boolean;

  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  oneWaySurcharge?: number;
}

export class UpdateLocationMatrixDto {
  @IsArray()
  matrix: LocationMatrixItemDto[];
}

