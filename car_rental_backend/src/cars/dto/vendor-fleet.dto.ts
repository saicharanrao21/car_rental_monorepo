import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { VehicleOperationalStatus, VehicleVerificationStatus } from '@prisma/client';

export class AssignServiceAreaDto {
  @IsNotEmpty()
  @IsString()
  serviceAreaId: string;
}

export class StartMaintenanceDto {
  @IsNotEmpty()
  @IsString()
  reason: string;

  @IsOptional()
  @IsDateString()
  expectedReturnDate?: string;

  @IsOptional()
  @IsBoolean()
  overrideConflictingBookings?: boolean;
}

export class CompleteMaintenanceDto {
  @IsOptional()
  @IsString()
  notes?: string;
}

export class AdminVerifyVehicleDto {
  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsBoolean()
  autoActivate?: boolean;
}

export class AdminRejectVehicleDto {
  @IsNotEmpty()
  @IsString()
  reason: string;
}

export class AdminSuspendVehicleDto {
  @IsNotEmpty()
  @IsString()
  reason: string;
}

export class AdminRetireVehicleDto {
  @IsNotEmpty()
  @IsString()
  reason: string;
}

export class AdminFleetQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number = 20;

  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @IsString()
  vendorId?: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  serviceAreaId?: string;

  @IsOptional()
  @IsEnum(VehicleOperationalStatus)
  operationalStatus?: VehicleOperationalStatus;

  @IsOptional()
  @IsEnum(VehicleVerificationStatus)
  verificationStatus?: VehicleVerificationStatus;
}
