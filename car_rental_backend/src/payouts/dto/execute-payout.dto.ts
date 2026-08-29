import { IsOptional, IsString, IsNumber } from 'class-validator';

export class ExecutePayoutDto {
  @IsOptional()
  @IsString()
  providerTransferId?: string;

  @IsOptional()
  @IsNumber()
  providerFee?: number;

  @IsOptional()
  @IsString()
  adminNotes?: string;
}
