import { IsBoolean, IsEnum, IsNumber, IsOptional, IsString, Min } from 'class-validator';
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
  tripType?: string;

  @IsOptional()
  @IsEnum(SortByOption)
  sortBy?: SortByOption = SortByOption.RECOMMENDED;
}
