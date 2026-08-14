import {
  Controller,
  Post,
  Body,
  Get,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
  HttpException,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { RegisterDto } from './dto/register.dto';
import { RegisterVendorDto } from './dto/register-vendor.dto';
import { AdminLoginDto } from './dto/admin-login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

import { RateLimiterGuard } from '../common/guards/rate-limiter.guard';
import { RateLimit } from '../common/decorators/rate-limit.decorator';

@Controller('auth')
@UseGuards(RateLimiterGuard)
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('otp/send')
  @RateLimit({ limit: 5, ttlSeconds: 60 })
  @HttpCode(HttpStatus.OK)
  async sendOtp(@Body() dto: SendOtpDto) {
    await this.authService.sendOtp(dto.phone);
    return { message: 'OTP sent successfully' };
  }

  @Post('otp/verify')
  @RateLimit({ limit: 10, ttlSeconds: 60 })
  @HttpCode(HttpStatus.OK)
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtpAndLogin(dto.phone, dto.otp);
  }

  @Post('register')
  @RateLimit({ limit: 10, ttlSeconds: 60 })
  @HttpCode(HttpStatus.CREATED)
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto.phone, dto.name, dto.email);
  }

  @Post('register-vendor')
  @RateLimit({ limit: 10, ttlSeconds: 60 })
  @HttpCode(HttpStatus.CREATED)
  async registerVendor(@Body() dto: RegisterVendorDto) {
    return this.authService.registerVendor(dto);
  }

  @Post('admin/login')
  @RateLimit({ limit: 5, ttlSeconds: 60 })
  @HttpCode(HttpStatus.OK)
  async adminLogin(@Body() dto: AdminLoginDto) {
    return this.authService.adminLogin(dto.email, dto.password);
  }

  @Post('refresh')
  @RateLimit({ limit: 30, ttlSeconds: 60 })
  @HttpCode(HttpStatus.OK)
  async refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshTokens(dto.refreshToken);
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  async logout(@Body() dto: RefreshTokenDto) {
    await this.authService.logout(dto.refreshToken);
    return { message: 'Logged out successfully' };
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async getMe(@Req() req: any) {
    const userId = req.user.userId;
    if (!userId) {
      throw new HttpException('Unauthorized', HttpStatus.UNAUTHORIZED);
    }
    const user = await this.authService.getUserById(userId);
    if (!user) {
      throw new HttpException('User not found', HttpStatus.NOT_FOUND);
    }
    return user;
  }
}
