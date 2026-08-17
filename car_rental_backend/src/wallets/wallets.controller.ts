import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
  ParseIntPipe,
  DefaultValuePipe,
} from '@nestjs/common';
import { WalletsService } from './wallets.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { CreateDepositOrderDto } from './dto/create-deposit-order.dto';
import { VerifyDepositDto } from './dto/verify-deposit.dto';
import { AdminAdjustWalletDto } from './dto/admin-adjust-wallet.dto';

@Controller('wallet')
@UseGuards(JwtAuthGuard, RolesGuard)
export class WalletsController {
  constructor(private readonly walletsService: WalletsService) {}

  /**
   * Get current authenticated customer's wallet.
   */
  @Get()
  async getMyWallet(@Req() req: any) {
    return this.walletsService.getWalletByUserId(req.user.id);
  }

  /**
   * Get current authenticated customer's wallet transactions.
   */
  @Get('transactions')
  async getMyTransactions(
    @Req() req: any,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    return this.walletsService.getWalletTransactions(req.user.id, page, limit);
  }

  /**
   * Create Razorpay order to add money to wallet.
   */
  @Post('deposit/create-order')
  async createDepositOrder(
    @Req() req: any,
    @Body() dto: CreateDepositOrderDto,
  ) {
    return this.walletsService.createDepositOrder(req.user.id, dto.amount);
  }

  /**
   * Verify Razorpay deposit payment and credit wallet.
   */
  @Post('deposit/verify')
  async verifyDeposit(
    @Req() req: any,
    @Body() dto: VerifyDepositDto,
  ) {
    return this.walletsService.verifyDepositPayment(req.user.id, dto);
  }

  /**
   * Admin manual adjustment with mandatory reason and AuditLog.
   */
  @Post('admin/adjust')
  @Roles(Role.ADMIN)
  async adminAdjust(
    @Req() req: any,
    @Body() dto: AdminAdjustWalletDto,
  ) {
    return this.walletsService.adminAdjustWallet(req.user.id, dto);
  }

  /**
   * Admin inspect wallet details & reconciliation status.
   */
  @Get('admin/:walletId/reconcile')
  @Roles(Role.ADMIN)
  async adminReconcile(@Param('walletId') walletId: string) {
    return this.walletsService.reconcileWallet(walletId);
  }
}
