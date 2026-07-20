import { IsBoolean, IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { PaginationDto } from '../../common/pagination.dto';
import { CarCategory } from '@prisma/client';

export enum SortByOption {
  PRICE_ASC = 'PRICE_ASC',
  PRICE_DESC = 'PRICE_DESC',
  RATING = 'RATING',
  RELEVANCE = 'RELEVANCE',
}

export class CarsQueryDto extends PaginationDto {
  @IsNotEmpty()
  @IsString()
  city: string;

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
  sortBy?: SortByOption = SortByOption.RELEVANCE;
}
