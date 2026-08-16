import {
  IsString,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsDateString,
  IsNumber,
  Min,
} from 'class-validator';
import { TripType, DeliveryType } from '@prisma/client';

export class CreateBookingDto {
  @IsString()
  @IsNotEmpty()
  carId: string;

  @IsEnum(TripType)
  @IsNotEmpty()
  tripType: TripType;

  @IsString()
  @IsNotEmpty()
  pickupLocation: string;

  @IsString()
  @IsOptional()
  dropLocation?: string;

  @IsDateString()
  @IsNotEmpty()
  startDate: string;

  @IsDateString()
  @IsNotEmpty()
  endDate: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  distanceKm?: number;

  @IsString()
  @IsOptional()
  couponCode?: string;

  @IsOptional()
  driverIncluded?: boolean;

  @IsOptional()
  childSeat?: boolean;

  @IsOptional()
  extraLuggage?: boolean;

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

  @IsNumber()
  @Min(0)
  @IsOptional()
  deliveryFee?: number;

  @IsString()
  @IsOptional()
  pickupAddress?: string;

  @IsNumber()
  @IsOptional()
  pickupLatitude?: number;

  @IsNumber()
  @IsOptional()
  pickupLongitude?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  pickupFee?: number;
}
