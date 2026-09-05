import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Req,
} from '@nestjs/common';
import { PricingService } from './pricing.service';
import { CreateQuoteDto } from './dto/create-quote.dto';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Role } from '@prisma/client';

@Controller('pricing')
export class PricingController {
  constructor(
    private readonly pricingService: PricingService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  /**
   * Generates a canonical server-authoritative quote for a vehicle reservation.
   */
  @Post('quote')
  async createQuote(@Req() req: any, @Body() dto: CreateQuoteDto) {
    const user = await this.getAuthUser(req);
    return this.pricingService.generateQuote(dto, user);
  }

  /**
   * Retrieves an existing quote and its itemized breakdown.
   */
  @Get('quote/:id')
  async getQuote(@Req() req: any, @Param('id') id: string) {
    const user = await this.getAuthUser(req);
    return this.pricingService.getQuoteById(id, user);
  }

  /**
   * Refreshes an expired or stale quote with current prices.
   */
  @Post('quote/:id/refresh')
  async refreshQuote(@Req() req: any, @Param('id') id: string) {
    const user = await this.getAuthUser(req);
    return this.pricingService.refreshQuote(id, user);
  }

  // --- Helper Methods ---

  private async getAuthUser(
    req: any,
  ): Promise<{ userId: string; role: Role } | undefined> {
    const authHeader = req.headers?.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return undefined;
    }
    const token = authHeader.split(' ')[1];
    const secret =
      this.configService.get<string>('JWT_ACCESS_SECRET') ||
      'dev_access_secret_key_change_me_12345!';
    try {
      const verified: any = await this.jwtService.verifyAsync(token, {
        secret,
      });
      if (verified && verified.userId && verified.role) {
        return { userId: verified.userId, role: verified.role };
      }
      return undefined;
    } catch {
      return undefined;
    }
  }
}
