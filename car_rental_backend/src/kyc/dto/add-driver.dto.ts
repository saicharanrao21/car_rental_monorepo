import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsDateString,
  IsEmail,
} from 'class-validator';

export class AddDriverDto {
  @IsString()
  @IsNotEmpty()
  fullName: string;

  @IsString()
  @IsNotEmpty()
  phone: string;

  @IsEmail()
  @IsOptional()
  email?: string;

  @IsString()
  @IsNotEmpty()
  licenceNumber: string;

  @IsString()
  @IsNotEmpty()
  licenceFrontUrl: string;

  @IsString()
  @IsNotEmpty()
  licenceBackUrl: string;

  @IsDateString()
  @IsNotEmpty()
  expiryDate: string;
}
