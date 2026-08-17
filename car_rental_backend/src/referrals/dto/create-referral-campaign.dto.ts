import {
  IsString,
  IsNotEmpty,
  IsNumber,
  Min,
  IsOptional,
  IsBoolean,
  IsDateString,
  IsInt,
} from 'class-validator';

export class CreateReferralCampaignDto {
  @IsString()
  @IsNotEmpty({ message: 'Campaign name is required.' })
  name: string;

  @IsString()
  @IsNotEmpty({ message: 'Campaign code is required.' })
  code: string;

  @IsNumber()
  @Min(0, { message: 'Referrer reward amount must be >= 0.' })
  referrerRewardAmount: number;

  @IsNumber()
  @Min(0, { message: 'Referee reward amount must be >= 0.' })
  refereeRewardAmount: number;

  @IsNumber()
  @Min(100, { message: 'Minimum booking amount must be at least ₹100.' })
  minBookingAmount: number;

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
