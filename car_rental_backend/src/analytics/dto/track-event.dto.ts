import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class TrackAnalyticsEventDto {
  @IsNotEmpty()
  @IsString()
  eventType: string;

  @IsOptional()
  @IsString()
  userId?: string;

  @IsOptional()
  @IsString()
  vendorId?: string;

  @IsOptional()
  @IsString()
  carId?: string;

  @IsOptional()
  @IsString()
  bookingId?: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  sessionId?: string;

  @IsOptional()
  @IsString()
  platform?: string; // IOS, ANDROID, WEB

  @IsOptional()
  @IsString()
  source?: string; // ORGANIC, FEATURED, SPONSORED, REFERRAL, COUPON, CAMPAIGN, DIRECT

  @IsOptional()
  metadata?: any;

  @IsOptional()
  @IsString()
  idempotencyKey?: string;
}
