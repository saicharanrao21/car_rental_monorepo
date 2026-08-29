import {
  IsBoolean,
  IsEnum,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';
import { PaginationDto } from '../../common/pagination.dto';
import { CarCategory } from '@prisma/client';

export enum SortByOption {
  PRICE_ASC = 'PRICE_ASC',
  PRICE_DESC = 'PRICE_DESC',
  RATING = 'RATING',
  RELEVANCE = 'RELEVANCE',
  NEAREST = 'NEAREST',
  RECOMMENDED = 'RECOMMENDED',
}

export class CarsQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lat?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lng?: number;

  @IsOptional()
  @IsEnum(CarCategory)
  carType?: CarCategory;

  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  isAC?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  minPrice?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  maxPrice?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  minRating?: number;

  @IsOptional()
  @IsString()
  pickupHubId?: string;

  @IsOptional()
  @IsString()
  tripType?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(150)
  radiusKm?: number;

  @IsOptional()
  @IsString()
  fuelType?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  seating?: number;

  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  featuredOnly?: boolean;

  @IsOptional()
  @IsEnum(SortByOption)
  sortBy?: SortByOption = SortByOption.RECOMMENDED;

  @IsOptional()
  @IsISO8601()
  startDate?: string;

  @IsOptional()
  @IsISO8601()
  endDate?: string;
}
