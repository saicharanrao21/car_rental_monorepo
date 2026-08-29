import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateNotificationPreferencesDto {
  @IsOptional()
  @IsBoolean()
  promotionalPush?: boolean;

  @IsOptional()
  @IsBoolean()
  promotionalSms?: boolean;

  @IsOptional()
  @IsBoolean()
  promotionalEmail?: boolean;

  @IsOptional()
  @IsBoolean()
  promotionalWhatsApp?: boolean;

  @IsOptional()
  @IsBoolean()
  operationalPush?: boolean;

  @IsOptional()
  @IsBoolean()
  operationalSms?: boolean;

  @IsOptional()
  @IsBoolean()
  operationalEmail?: boolean;

  @IsOptional()
  @IsBoolean()
  operationalWhatsApp?: boolean;
}
