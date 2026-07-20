import { IsNotEmpty, Matches } from 'class-validator';

export class VerifyOtpDto {
  @IsNotEmpty()
  @Matches(/^[6-9]\d{9}$/, {
    message: 'Phone number must be a valid 10-digit Indian mobile number',
  })
  phone: string;

  @IsNotEmpty()
  @Matches(/^\d{6}$/, {
    message: 'OTP must be a 6-digit numeric string',
  })
  otp: string;
}
