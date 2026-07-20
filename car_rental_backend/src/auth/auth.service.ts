import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { OtpService } from './otp.service';
import { Role, User, VerificationStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  private readonly accessSecret: string;
  private readonly refreshSecret: string;
  private readonly accessExpiry: string;
  private readonly refreshExpiry: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly otpService: OtpService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {
    this.accessSecret = this.configService.get<string>('JWT_ACCESS_SECRET') || 'dev_access_secret_key_change_me_12345!';
    this.refreshSecret = this.configService.get<string>('JWT_REFRESH_SECRET') || 'dev_refresh_secret_key_change_me_12345!';
    this.accessExpiry = this.configService.get<string>('JWT_ACCESS_EXPIRY') || '15m';
    this.refreshExpiry = this.configService.get<string>('JWT_REFRESH_EXPIRY') || '30d';
  }

  async sendOtp(phone: string): Promise<void> {
    await this.otpService.sendOtp(phone);
  }

  async verifyOtpAndLogin(phone: string, otp: string) {
    // 1. Verify OTP first
    await this.otpService.verifyOtp(phone, otp);

    // 2. Check if user already exists (include vendor for VENDOR role)
    const user = await this.prisma.user.findUnique({
      where: { phone },
      include: {
        vendor: true,
      },
    });

    if (!user) {
      // User is new, registration is required
      return { isNewUser: true };
    }

    if (user.banned) {
      throw new HttpException('This user account has been banned.', HttpStatus.FORBIDDEN);
    }

    // 3. User exists, issue token pair
    const tokens = await this.issueTokens(user.id, user.role);

    return {
      isNewUser: false,
      user,
      ...tokens,
    };
  }

  async register(phone: string, name: string, email?: string) {
    // 1. Re-verify phone has a recent verified OTP request in last 10 minutes
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
    const recentVerifiedOtp = await this.prisma.otpRequest.findFirst({
      where: {
        phone,
        verified: true,
        createdAt: { gte: tenMinutesAgo },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    if (!recentVerifiedOtp) {
      throw new HttpException(
        'Phone number verification required or expired. Please verify OTP first.',
        HttpStatus.BAD_REQUEST,
      );
    }

    // 2. Check if user already exists
    let user = await this.prisma.user.findUnique({
      where: { phone },
    });

    if (user) {
      throw new HttpException('A user with this phone number already exists.', HttpStatus.BAD_REQUEST);
    }

    // 3. Create the user
    user = await this.prisma.user.create({
      data: {
        phone,
        name,
        email,
        role: Role.CUSTOMER, // Customers default
      },
    });

    // 4. Issue tokens
    const tokens = await this.issueTokens(user.id, user.role);

    return {
      user,
      ...tokens,
    };
  }

  async registerVendor(dto: any) {
    const { phone, businessName, ownerName, city, gstNumber, panNumber, bankDetails, businessType, yearsInOperation } = dto;

    // 1. Verify phone has a recent verified OTP request in last 10 minutes
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
    const recentVerifiedOtp = await this.prisma.otpRequest.findFirst({
      where: {
        phone,
        verified: true,
        createdAt: { gte: tenMinutesAgo },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    if (!recentVerifiedOtp) {
      throw new HttpException(
        'Phone number verification required or expired. Please verify OTP first.',
        HttpStatus.BAD_REQUEST,
      );
    }

    // 2. Check if user already exists
    let user = await this.prisma.user.findUnique({
      where: { phone },
    });

    if (user) {
      throw new HttpException('A user with this phone number already exists.', HttpStatus.BAD_REQUEST);
    }

    // 3. Create BOTH User and Vendor in a single transaction
    const result = await this.prisma.$transaction(async (tx) => {
      const newUser = await tx.user.create({
        data: {
          phone,
          name: ownerName,
          email: `${ownerName.toLowerCase().replace(/\s+/g, '.')}@vendor.com`, // Stub email
          role: Role.VENDOR,
        },
      });

      const newVendor = await tx.vendor.create({
        data: {
          userId: newUser.id,
          businessName,
          ownerName,
          city,
          gstNumber,
          panNumber,
          bankDetails,
          businessType,
          yearsInOperation: yearsInOperation || null,
          verificationStatus: VerificationStatus.PENDING,
        },
      });

      return { user: newUser, vendor: newVendor };
    });

    // 4. Issue tokens
    const tokens = await this.issueTokens(result.user.id, result.user.role);

    return {
      user: {
        ...result.user,
        vendor: result.vendor,
      },
      ...tokens,
    };
  }

  async adminLogin(email: string, password: string) {
    // 1. Look up user by email
    const user = await this.prisma.user.findFirst({
      where: {
        email,
        role: Role.ADMIN,
      },
    });

    if (!user || !user.passwordHash) {
      throw new HttpException('Invalid email or password', HttpStatus.UNAUTHORIZED);
    }

    // 2. Validate password hash
    const isMatch = bcrypt.compareSync(password, user.passwordHash);
    if (!isMatch) {
      throw new HttpException('Invalid email or password', HttpStatus.UNAUTHORIZED);
    }

    if (user.banned) {
      throw new HttpException('This account has been banned.', HttpStatus.FORBIDDEN);
    }

    // 3. Issue tokens
    const tokens = await this.issueTokens(user.id, user.role);

    return {
      user,
      ...tokens,
    };
  }

  async refreshTokens(refreshToken: string) {
    try {
      // 1. Verify JWT signature
      const payload = this.jwtService.verify(refreshToken, {
        secret: this.refreshSecret,
      });

      const tokenId = payload.tokenId;
      const userId = payload.sub;

      if (!tokenId || !userId) {
        throw new HttpException('Invalid token payload', HttpStatus.UNAUTHORIZED);
      }

      // 2. Look up the token in the RefreshToken table
      const storedToken = await this.prisma.refreshToken.findUnique({
        where: { id: tokenId },
      });

      if (!storedToken || storedToken.revoked || storedToken.expiresAt < new Date()) {
        throw new HttpException('Refresh token has expired or is revoked', HttpStatus.UNAUTHORIZED);
      }

      // 3. Confirm hash match
      const isMatch = bcrypt.compareSync(refreshToken, storedToken.tokenHash);
      if (!isMatch) {
        throw new HttpException('Invalid refresh token signature match', HttpStatus.UNAUTHORIZED);
      }

      // 4. Rotate tokens: Revoke old token and issue new pair
      await this.prisma.refreshToken.update({
        where: { id: tokenId },
        data: { revoked: true },
      });

      // 5. Look up user
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
      });

      if (!user || user.banned) {
        throw new HttpException('User not found or banned', HttpStatus.UNAUTHORIZED);
      }

      const tokens = await this.issueTokens(user.id, user.role);

      return tokens;
    } catch (err) {
      throw new HttpException('Invalid refresh token', HttpStatus.UNAUTHORIZED);
    }
  }

  async logout(refreshToken: string): Promise<void> {
    try {
      // Decode or verify token to get tokenId
      const payload = this.jwtService.verify(refreshToken, {
        secret: this.refreshSecret,
      });

      const tokenId = payload.tokenId;
      if (tokenId) {
        await this.prisma.refreshToken.update({
          where: { id: tokenId },
          data: { revoked: true },
        });
      }
    } catch (err) {
      // Ignore token verification errors during logout for reliability
    }
  }

  async getUserById(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        vendor: true,
      },
    });
  }

  // --- Helper Methods ---

  private async issueTokens(userId: string, role: Role) {
    // 1. Create RefreshToken record in DB first to obtain UUID/CUID
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days
    const tokenRecord = await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: '',
        expiresAt,
      },
    });

    // 2. Generate access and refresh tokens
    const accessToken = this.jwtService.sign(
      { userId, role },
      {
        secret: this.accessSecret,
        expiresIn: this.accessExpiry as any,
      },
    );

    const refreshToken = this.jwtService.sign(
      { sub: userId, tokenId: tokenRecord.id },
      {
        secret: this.refreshSecret,
        expiresIn: this.refreshExpiry as any,
      },
    );

    // 3. Hash and store the refresh token
    const tokenHash = bcrypt.hashSync(refreshToken, 10);
    await this.prisma.refreshToken.update({
      where: { id: tokenRecord.id },
      data: { tokenHash },
    });

    return {
      accessToken,
      refreshToken,
    };
  }
}
