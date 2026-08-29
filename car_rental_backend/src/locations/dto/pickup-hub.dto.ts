import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsNumber,
  IsBoolean,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreatePickupHubDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  address: string;

  @IsString()
  @IsOptional()
  locality?: string;

  @IsString()
  @IsNotEmpty()
  city: string;

  @IsString()
  @IsOptional()
  state?: string;

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
  @Min(1)
  @Max(150)
  @IsOptional()
  @Type(() => Number)
  serviceRadiusKm?: number;

  @IsString()
  @IsOptional()
  operatingHours?: string;

  @IsString()
  @IsOptional()
  contactPhone?: string;
}

export class UpdatePickupHubDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  address?: string;

  @IsString()
  @IsOptional()
  locality?: string;

  @IsString()
  @IsOptional()
  city?: string;

  @IsString()
  @IsOptional()
  state?: string;

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
  @Min(1)
  @Max(150)
  @IsOptional()
  @Type(() => Number)
  serviceRadiusKm?: number;

  @IsString()
  @IsOptional()
  operatingHours?: string;

  @IsString()
  @IsOptional()
  contactPhone?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

export class PickupHubQueryDto {
  @IsString()
  @IsOptional()
  city?: string;

  @IsString()
  @IsOptional()
  vendorId?: string;

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  lat?: number;

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  lng?: number;

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  radiusKm?: number;
}
