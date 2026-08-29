import {
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class RecordAttributionDto {
  @IsNotEmpty()
  @IsString()
  bookingId: string;

  @IsNotEmpty()
  @IsString()
  source: string; // ORGANIC, FEATURED, SPONSORED, REFERRAL, COUPON, CAMPAIGN

  @IsOptional()
  @IsString()
  campaignId?: string;

  @IsOptional()
  @IsString()
  sponsoredCampaignId?: string;

  @IsOptional()
  @IsString()
  referralAttributionId?: string;

  @IsOptional()
  @IsString()
  couponId?: string;

  @IsOptional()
  metadata?: any;
}
