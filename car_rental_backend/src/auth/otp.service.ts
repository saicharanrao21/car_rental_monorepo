import { HttpException, HttpStatus, Inject, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SmsProviderService } from './sms-provider.service';
import { REDIS_CLIENT } from '../redis/redis.module';
import Redis from 'ioredis';
import * as bcrypt from 'bcrypt';

@Injectable()
export class OtpService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly smsProvider: SmsProviderService,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
  ) { }

  async sendOtp(phone: string): Promise<void> {
    const rateLimitKey = `otp:ratelimit:${phone}`;

    // Check if the rate limit key exists in Redis
    const isRateLimited = await this.redis.get(rateLimitKey);
    if (isRateLimited) {
      throw new HttpException(
        'Please wait 60 seconds before requesting another OTP',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // Generate 6-digit numeric OTP code
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const otpHash = bcrypt.hashSync(otpCode, 10);
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes validity

    // Store in durable OtpRequest table
    await this.prisma.otpRequest.create({
      data: {
        phone,
        otpHash,
        expiresAt,
      },
    });

    // Set rate limit key in Redis with 60s TTL
    await this.redis.set(rateLimitKey, '1', 'EX', 60);

    // Send the OTP via the agnostic SMS provider
    const message = `Your DriveGo OTP is ${otpCode}. It is valid for 5 minutes.`;
    await this.smsProvider.sendSms(phone, message);
  }

  async verifyOtp(phone: string, otp: string): Promise<boolean> {
    // Find the latest unverified, unexpired OTP request for this phone number
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
      throw new HttpException('No OTP request found for this phone number', HttpStatus.BAD_REQUEST);
    }

    // Check if it has expired
    if (latestOtp.expiresAt < new Date()) {
      throw new HttpException('OTP has expired. Please request a new one.', HttpStatus.BAD_REQUEST);
    }

    // Check if attempt count exceeded (max 5 attempts)
    if (latestOtp.attemptCount >= 5) {
      throw new HttpException(
        'Too many invalid verification attempts. This OTP is now invalid.',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Compare input OTP code with stored hash
    const isMatch = bcrypt.compareSync(otp, latestOtp.otpHash);

    if (!isMatch) {
      // Increment attempt count
      await this.prisma.otpRequest.update({
        where: { id: latestOtp.id },
        data: { attemptCount: { increment: 1 } },
      });

      const attemptsRemaining = 5 - (latestOtp.attemptCount + 1);
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

    // Mark as verified on success
    await this.prisma.otpRequest.update({
      where: { id: latestOtp.id },
      data: { verified: true },
    });

    return true;
  }
}
