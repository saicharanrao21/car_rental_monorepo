import {
  IsISO8601,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateFeaturedListingDto {
  @IsNotEmpty()
  @IsString()
  carId: string;

  @IsNotEmpty()
  @IsString()
  city: string;

  @IsNotEmpty()
  @IsISO8601()
  startDate: string;

  @IsNotEmpty()
  @IsISO8601()
  endDate: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(10)
  priority?: number;
}
