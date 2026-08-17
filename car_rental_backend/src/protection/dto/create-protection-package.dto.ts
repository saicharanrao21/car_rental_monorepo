import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
} from 'class-validator';
import { ProtectionPlanCode } from '@prisma/client';

export class CreateProtectionPackageDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsEnum(ProtectionPlanCode)
  @IsNotEmpty()
  code: ProtectionPlanCode;

  @IsString()
  @IsNotEmpty()
  description: string;

  @IsNumber()
  @IsNotEmpty()
  dailyRate: number;

  @IsArray()
  @IsString({ each: true })
  @IsNotEmpty()
  coverageSummary: string[];

  @IsNumber()
  @IsNotEmpty()
  deductibleAmount: number;

  @IsNumber()
  @IsNotEmpty()
  maxCoverageAmount: number;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  exclusions?: string[];

  @IsString()
  @IsOptional()
  termsUrl?: string;

  @IsString()
  @IsOptional()
  city?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsInt()
  @IsOptional()
  displayOrder?: number;
}
