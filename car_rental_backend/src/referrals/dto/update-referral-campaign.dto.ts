import {
  IsString,
  IsNumber,
  Min,
  IsOptional,
  IsBoolean,
  IsDateString,
  IsInt,
} from 'class-validator';

export class UpdateReferralCampaignDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  referrerRewardAmount?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  refereeRewardAmount?: number;

  @IsNumber()
  @Min(100)
  @IsOptional()
  minBookingAmount?: number;

  @IsString()
  @IsOptional()
  city?: string;

  @IsDateString()
  @IsOptional()
  startDate?: string;

  @IsDateString()
  @IsOptional()
  endDate?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsInt()
  @Min(1)
  @IsOptional()
  maxReferralsPerUser?: number;
}
