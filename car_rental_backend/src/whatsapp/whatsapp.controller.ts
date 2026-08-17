import {
  Controller,
  Get,
  Post,
  Query,
  Body,
  Headers,
  HttpCode,
  HttpStatus,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { WhatsAppService } from './whatsapp.service';
import { WhatsAppWebhookPayload } from './whatsapp.types';

@Controller('whatsapp')
export class WhatsAppController {
  private readonly logger = new Logger(WhatsAppController.name);
  private readonly verifyToken: string;

  constructor(
    private readonly whatsappService: WhatsAppService,
    private readonly configService: ConfigService,
  ) {
    this.verifyToken =
      this.configService.get<string>('WHATSAPP_WEBHOOK_VERIFY_TOKEN') ||
      'drivego_whatsapp_verify_token';
  }

  /**
   * Meta Webhook Verification Challenge (GET /whatsapp/webhook)
   */
  @Get('webhook')
  verifyWebhook(
    @Query('hub.mode') mode: string,
    @Query('hub.verify_token') token: string,
    @Query('hub.challenge') challenge: string,
  ) {
    if (mode === 'subscribe' && token === this.verifyToken) {
      this.logger.log('Meta WhatsApp webhook verification successful.');
      return challenge;
    }

    this.logger.warn(`Meta WhatsApp webhook verification failed for token: ${token}`);
    throw new ForbiddenException('Invalid webhook verification token.');
  }

  /**
   * Inbound WhatsApp Delivery Status Webhook (POST /whatsapp/webhook)
   */
  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  async handleWebhook(
    @Body() payload: any,
    @Headers('x-hub-signature-256') signature?: string,
  ) {
    // Note: Signature verification can be performed against raw payload when configured
    const result = await this.whatsappService.handleWebhookEvent(payload);
    return { status: 'ok', processed: result.processed };
  }
}
