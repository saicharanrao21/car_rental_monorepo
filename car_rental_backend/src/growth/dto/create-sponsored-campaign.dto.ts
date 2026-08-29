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

export class CreateSponsoredCampaignDto {
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
  @Min(1.0)
  @Max(2.0)
  boostMultiplier?: number; // Capped at 2.0x for marketplace fairness
}
