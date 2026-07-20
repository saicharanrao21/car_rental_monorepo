import { IsString, IsEnum, IsNotEmpty, IsOptional, IsDateString, IsNumber, Min } from 'class-validator';
import { TripType } from '@prisma/client';

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
}
