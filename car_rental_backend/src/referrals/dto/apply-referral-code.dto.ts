import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class ApplyReferralCodeDto {
  @IsString()
  @IsNotEmpty({ message: 'Referral code is required.' })
  referralCode: string;

  @IsString()
  @IsOptional()
  city?: string;
}
