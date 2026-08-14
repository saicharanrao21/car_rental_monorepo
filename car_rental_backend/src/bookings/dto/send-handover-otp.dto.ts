import { IsEnum } from 'class-validator';
import { HandoverOtpType } from '@prisma/client';

export class SendHandoverOtpDto {
  @IsEnum(HandoverOtpType)
  otpType: HandoverOtpType;
}
