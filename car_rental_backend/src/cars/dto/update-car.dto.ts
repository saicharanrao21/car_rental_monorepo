import { IsArray, IsBoolean, IsEnum, IsInt, IsOptional, IsString, IsNumber, Min } from 'class-validator';
import { CarCategory, FuelType } from '@prisma/client';

export class UpdateCarDto {
  @IsOptional()
  @IsString()
  make?: string;

  @IsOptional()
  @IsString()
  model?: string;

  @IsOptional()
  @IsInt()
  @Min(1900)
  year?: number;

  @IsOptional()
  @IsEnum(CarCategory)
  type?: CarCategory;

  @IsOptional()
  @IsEnum(FuelType)
  fuelType?: FuelType;

  @IsOptional()
  @IsInt()
  @Min(1)
  seating?: number;

  @IsOptional()
  @IsBoolean()
  isAC?: boolean;

  @IsOptional()
  @IsString()
  registrationNumber?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  photos?: string[];

  @IsOptional()
  @IsNumber()
  @Min(0)
  pricePerKm?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  pricePerDay?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  pricePerHour?: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  availableTripTypes?: string[];
}
