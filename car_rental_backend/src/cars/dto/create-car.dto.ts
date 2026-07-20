import { IsArray, IsBoolean, IsEnum, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { CarCategory, FuelType } from '@prisma/client';

export class CreateCarDto {
  @IsNotEmpty()
  @IsString()
  make: string;

  @IsNotEmpty()
  @IsString()
  model: string;

  @IsNotEmpty()
  @IsInt()
  @Min(1900)
  year: number;

  @IsNotEmpty()
  @IsEnum(CarCategory)
  type: CarCategory;

  @IsNotEmpty()
  @IsEnum(FuelType)
  fuelType: FuelType;

  @IsNotEmpty()
  @IsInt()
  @Min(1)
  seating: number;

  @IsNotEmpty()
  @IsBoolean()
  isAC: boolean;

  @IsNotEmpty()
  @IsString()
  registrationNumber: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  photos?: string[];

  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  pricePerKm: number;

  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  pricePerDay: number;

  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  pricePerHour: number;

  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean = true;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  availableTripTypes?: string[] = [];
}
