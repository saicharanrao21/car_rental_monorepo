import { IsOptional, IsString } from 'class-validator';

export class ReleaseCollateralDto {
  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsString()
  customerAcknowledgementSignatureUrl?: string;
}

