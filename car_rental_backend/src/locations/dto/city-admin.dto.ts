import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsNumber,
  IsBoolean,
  IsArray,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateSupportedCityDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  state: string;

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

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  enabledTripTypes?: string[];

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

export class UpdateSupportedCityDto {
  @IsString()
  @IsOptional()
  name?: string;

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

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  enabledTripTypes?: string[];

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}
