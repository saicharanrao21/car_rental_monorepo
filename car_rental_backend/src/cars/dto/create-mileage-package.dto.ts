import {
  IsString,
  IsNotEmpty,
  IsEnum,
  IsOptional,
  IsNumber,
  Min,
  IsBoolean,
} from 'class-validator';
import { TripType } from '@prisma/client';

export class CreateMileagePackageDto {
  @IsEnum(TripType)
  @IsNotEmpty()
  tripType: TripType;

  @IsString()
  @IsNotEmpty()
  name: string;

  @IsNumber()
  @Min(1)
  @IsOptional()
  includedKmPerDay?: number | null;

  @IsBoolean()
  @IsOptional()
  isUnlimited?: boolean;

  @IsNumber()
  @Min(1)
  basePricePerDay: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  extraKmRate?: number;

  @IsBoolean()
  @IsOptional()
  isDefault?: boolean;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}
