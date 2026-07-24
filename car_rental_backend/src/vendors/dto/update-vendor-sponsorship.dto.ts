import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class UpdateVendorSponsorshipDto {
  @IsBoolean()
  isSponsored: boolean;

  @IsOptional()
  @IsString()
  boostExpiresAt?: string;
}
