import { IsString, IsNotEmpty, IsOptional, IsNumber, IsEnum } from 'class-validator';
import { TripType, CarCategory } from '@prisma/client';

export class ValidateCouponDto {
  @IsString()
  @IsNotEmpty()
  code: string;

  @IsString()
  @IsOptional()
  carId?: string;

  @IsNumber()
  @IsOptional()
  subtotal?: number;

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
