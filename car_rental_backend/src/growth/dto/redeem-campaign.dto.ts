import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsEnum,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { CarCategory } from '@prisma/client';

export class ValidateCampaignDto {
  @IsNotEmpty()
  @IsString()
  code: string;

  @IsNotEmpty()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  bookingAmount: number;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsEnum(CarCategory)
  carCategory?: CarCategory;
}

export class RedeemCampaignDto extends ValidateCampaignDto {
  @IsNotEmpty()
  @IsString()
  bookingId: string;

  @IsNotEmpty()
  @IsString()
  customerId: string;
}

