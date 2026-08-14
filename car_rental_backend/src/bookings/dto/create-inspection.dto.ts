import {
  IsEnum,
  IsNumber,
  IsInt,
  Min,
  Max,
  IsOptional,
  IsString,
  IsArray,
  IsBoolean,
} from 'class-validator';
import { InspectionType } from '@prisma/client';

export class CreateInspectionDto {
  @IsEnum(InspectionType)
  type: InspectionType;

  @IsNumber()
  @Min(0, { message: 'Odometer reading cannot be negative' })
  odometer: number;

  @IsInt({ message: 'Fuel percentage must be an integer' })
  @Min(0, { message: 'Fuel percentage must be at least 0%' })
  @Max(100, { message: 'Fuel percentage cannot exceed 100%' })
  fuelPercent: number;

  @IsOptional()
  @IsString()
  conditionNotes?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  damagePhotos?: string[];

  @IsOptional()
  @IsBoolean()
  finalize?: boolean;
}
