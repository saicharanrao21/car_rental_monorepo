import {
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SmsProviderService } from './sms-provider.service';
import { REDIS_CLIENT } from '../redis/redis.module';
import Redis from 'ioredis';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly smsProvider: SmsProviderService,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
  ) {}

  async sendOtp(phone: string): Promise<void> {
    const rateLimitKey = `otp:ratelimit:${phone}`;

    // 1. Check if the rate limit key exists in Redis (60-second cooldown per phone)
    const isRateLimited = await this.redis.get(rateLimitKey);
    if (isRateLimited) {
      throw new HttpException(
        'Please wait 60 seconds before requesting another OTP',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // 2. Invalidate all existing active unverified OTP requests for this phone number
    await this.prisma.otpRequest.updateMany({
      where: {
        phone,
        verified: false,
      },
      data: {
        expiresAt: new Date(Date.now() - 1000), // explicitly expire older OTPs
      },
    });

    // 3. Generate 6-digit numeric OTP code using CSPRNG and bcrypt hash
    const otpCode = crypto.randomInt(100000, 1000000).toString();
    const otpHash = bcrypt.hashSync(otpCode, 10);
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes validity

    // 4. Store in durable OtpRequest table
    const otpRecord = await this.prisma.otpRequest.create({
      data: {
        phone,
        otpHash,
        expiresAt,
      },
    });

    // 5. Send the OTP via the SMS provider abstraction
    const message = `Your DriveGo OTP is ${otpCode}. It is valid for 5 minutes.`;
    try {
      await this.smsProvider.sendSms(phone, message, otpCode);
    } catch (err: any) {
      // Invalidate the un-dispatched OTP record so it cannot be guessed/verified
      await this.prisma.otpRequest.update({
        where: { id: otpRecord.id },
        data: { expiresAt: new Date(Date.now() - 1000) },
      });

      this.logger.error(
        `Failed to deliver OTP via SMS for phone ending in ${phone.slice(-4)}: ${err.message}`,
      );

      throw new HttpException(
        'Failed to deliver OTP via SMS. Please try again.',
        HttpStatus.BAD_GATEWAY,
      );
    }

    // 6. Set rate limit key in Redis with 60s TTL only after SMS dispatch was initiated
    await this.redis.set(rateLimitKey, '1', 'EX', 60);
  }

  async verifyOtp(phone: string, otp: string): Promise<boolean> {
    // 1. Find the latest unverified OTP request for this phone number
    const latestOtp = await this.prisma.otpRequest.findFirst({
      where: {
        phone,
        verified: false,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    if (!latestOtp) {
      throw new HttpException(
        'No OTP request found for this phone number',
        HttpStatus.BAD_REQUEST,
      );
    }

    // 2. Check if it has expired
    if (latestOtp.expiresAt < new Date()) {
      throw new HttpException(
        'OTP has expired. Please request a new one.',
        HttpStatus.BAD_REQUEST,
      );
    }

    // 3. Check if attempt count exceeded (max 5 attempts)
    if (latestOtp.attemptCount >= 5) {
      throw new HttpException(
        'Too many invalid verification attempts. This OTP is now invalid.',
        HttpStatus.BAD_REQUEST,
      );
    }

    // 4. Compare input OTP code with stored bcrypt hash
    const isMatch = bcrypt.compareSync(otp, latestOtp.otpHash);

    if (!isMatch) {
      const updatedCount = latestOtp.attemptCount + 1;
      const isExceeded = updatedCount >= 5;

      // Increment attempt count, and expire if exceeded
      await this.prisma.otpRequest.update({
        where: { id: latestOtp.id },
        data: {
          attemptCount: { increment: 1 },
          ...(isExceeded ? { expiresAt: new Date(Date.now() - 1000) } : {}),
        },
      });

      const attemptsRemaining = Math.max(0, 5 - updatedCount);
      if (attemptsRemaining <= 0) {
        throw new HttpException(
          'Too many invalid attempts. This OTP is now invalid.',
          HttpStatus.BAD_REQUEST,
        );
      } else {
        throw new HttpException(
          `Invalid OTP. ${attemptsRemaining} attempts remaining.`,
          HttpStatus.BAD_REQUEST,
        );
      }
    }

    // 5. Mark as verified on success and expire immediately to guarantee single-use
    await this.prisma.otpRequest.update({
      where: { id: latestOtp.id },
      data: {
        verified: true,
        expiresAt: new Date(Date.now() - 1000),
      },
    });

    // Invalidate any other unverified OTP requests for this phone number
    await this.prisma.otpRequest.updateMany({
      where: {
        phone,
        verified: false,
      },
      data: {
        expiresAt: new Date(Date.now() - 1000),
      },
    });

    return true;
  }
}
