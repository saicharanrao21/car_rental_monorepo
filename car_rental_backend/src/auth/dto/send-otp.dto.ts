import { IsNotEmpty, Matches } from 'class-validator';

export class SendOtpDto {
  @IsNotEmpty()
  @Matches(/^[6-9]\d{9}$/, {
    message: 'Phone number must be a valid 10-digit Indian mobile number',
  })
  phone: string;
}
