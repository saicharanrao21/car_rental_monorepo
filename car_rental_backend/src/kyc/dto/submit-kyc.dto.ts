import { IsString, IsNotEmpty, IsDateString, IsUrl } from 'class-validator';

export class SubmitKycDto {
  @IsString()
  @IsNotEmpty()
  licenceNumber!: string;

  @IsDateString()
  @IsNotEmpty()
  expiryDate!: string;

  @IsString()
  @IsNotEmpty()
  licenceFrontUrl!: string;

  @IsString()
  @IsNotEmpty()
  licenceBackUrl!: string;
}
