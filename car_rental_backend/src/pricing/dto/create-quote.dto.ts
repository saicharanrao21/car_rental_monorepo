import {
  IsString,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsDateString,
  IsNumber,
  Min,
  IsBoolean,
} from 'class-validator';
import { TripType, DeliveryType } from '@prisma/client';

export class CreateQuoteDto {
  @IsString()
  @IsNotEmpty()
  carId: string;

  @IsDateString()
  @IsNotEmpty()
  startDate: string;

  @IsDateString()
  @IsNotEmpty()
  endDate: string;

  @IsEnum(TripType)
  @IsNotEmpty()
  tripType: TripType;

  @IsString()
  @IsOptional()
  pickupLocation?: string;

  @IsString()
  @IsOptional()
  dropLocation?: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  distanceKm?: number;

  @IsString()
  @IsOptional()
  pickupHubId?: string;

  @IsString()
  @IsOptional()
  returnHubId?: string;

  @IsEnum(DeliveryType)
  @IsOptional()
  deliveryType?: DeliveryType;

  @IsString()
  @IsOptional()
  deliveryAddress?: string;

  @IsNumber()
  @IsOptional()
  deliveryLatitude?: number;

  @IsNumber()
  @IsOptional()
  deliveryLongitude?: number;

  @IsString()
  @IsOptional()
  pickupAddress?: string;

  @IsNumber()
  @IsOptional()
  pickupLatitude?: number;

  @IsNumber()
  @IsOptional()
  pickupLongitude?: number;

  @IsString()
  @IsOptional()
  couponCode?: string;

  @IsString()
  @IsOptional()
  protectionPackageId?: string;

  @IsString()
  @IsOptional()
  mileagePackageId?: string;

  @IsBoolean()
  @IsOptional()
  driverIncluded?: boolean;

  @IsBoolean()
  @IsOptional()
  childSeat?: boolean;

  @IsBoolean()
  @IsOptional()
  extraLuggage?: boolean;

  @IsString()
  @IsOptional()
  idempotencyKey?: string;
}
