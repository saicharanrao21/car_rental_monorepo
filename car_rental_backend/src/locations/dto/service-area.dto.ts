import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsNumber,
  IsBoolean,
  IsEnum,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ServiceAreaStatus } from '@prisma/client';

export { ServiceAreaStatus };

export type ServiceabilityState = 'SERVICEABLE' | 'COMING_SOON' | 'NO_MATCH';

export class CreateCityDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  state: string;

  @IsString()
  @IsOptional()
  country?: string = 'India';

  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  latitude: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  longitude: number;

  @IsString()
  @IsOptional()
  timezone?: string = 'Asia/Kolkata';

  @IsEnum(ServiceAreaStatus)
  @IsOptional()
  status?: ServiceAreaStatus = ServiceAreaStatus.ACTIVE;

  @IsOptional()
  enabledTripTypes?: string[] = [];
}

export class UpdateCityDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  state?: string;

  @IsString()
  @IsOptional()
  country?: string;

  @IsNumber()
  @Min(-90)
  @Max(90)
  @IsOptional()
  @Type(() => Number)
  latitude?: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @IsOptional()
  @Type(() => Number)
  longitude?: number;

  @IsString()
  @IsOptional()
  timezone?: string;

  @IsEnum(ServiceAreaStatus)
  @IsOptional()
  status?: ServiceAreaStatus;

  @IsOptional()
  enabledTripTypes?: string[];
}

export class SetCityStatusDto {
  @IsEnum(ServiceAreaStatus)
  status: ServiceAreaStatus;

  @IsString()
  @IsOptional()
  reason?: string;
}

export class CreateServiceAreaDto {
  @IsString()
  @IsNotEmpty()
  cityId: string;

  @IsString()
  @IsNotEmpty()
  name: string;

  @IsEnum(ServiceAreaStatus)
  @IsOptional()
  status?: ServiceAreaStatus = ServiceAreaStatus.ACTIVE;

  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  latitude: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  longitude: number;

  @IsNumber()
  @Min(100)
  @Max(100000)
  @IsOptional()
  @Type(() => Number)
  radiusMeters?: number = 5000;

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  priority?: number = 0;
}

export class UpdateServiceAreaDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  cityId?: string;

  @IsEnum(ServiceAreaStatus)
  @IsOptional()
  status?: ServiceAreaStatus;

  @IsNumber()
  @Min(-90)
  @Max(90)
  @IsOptional()
  @Type(() => Number)
  latitude?: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @IsOptional()
  @Type(() => Number)
  longitude?: number;

  @IsNumber()
  @Min(100)
  @Max(100000)
  @IsOptional()
  @Type(() => Number)
  radiusMeters?: number;

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  priority?: number;
}

export class SetServiceAreaStatusDto {
  @IsEnum(ServiceAreaStatus)
  status: ServiceAreaStatus;

  @IsString()
  @IsOptional()
  reason?: string;
}

export class AssignVendorServiceAreaDto {
  @IsString()
  @IsNotEmpty()
  vendorId: string;

  @IsString()
  @IsNotEmpty()
  serviceAreaId: string;

  @IsBoolean()
  @IsOptional()
  isPrimary?: boolean = false;
}

export class ServiceAreaQueryDto {
  @IsString()
  @IsOptional()
  cityId?: string;

  @IsString()
  @IsOptional()
  city?: string;

  @IsEnum(ServiceAreaStatus)
  @IsOptional()
  status?: ServiceAreaStatus;

  @IsString()
  @IsOptional()
  search?: string;
}

export class ServiceabilityQueryDto {
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  latitude: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  longitude: number;

  @IsString()
  @IsOptional()
  city?: string;

  @IsString()
  @IsOptional()
  serviceAreaId?: string;
}

export interface NearestServiceAreaInfo {
  id: string;
  name: string;
  cityName: string;
  cityId: string;
  distanceKm: number;
  latitude: number;
  longitude: number;
  status: ServiceAreaStatus;
}

export interface ResolvedServiceAreaResult {
  state: ServiceabilityState;
  resolvedCity?: {
    id: string;
    name: string;
    state: string;
    country: string;
    latitude: number;
    longitude: number;
    timezone: string;
  };
  resolvedServiceArea?: {
    id: string;
    name: string;
    status: ServiceAreaStatus;
    latitude: number;
    longitude: number;
    radiusMeters: number;
    priority: number;
  };
  message?: string;
  nearestActiveAreas: NearestServiceAreaInfo[];
  availableVendorsCount?: number;
}
