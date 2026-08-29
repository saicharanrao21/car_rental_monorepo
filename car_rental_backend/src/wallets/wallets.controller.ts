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
    const userId = req.user.id || req.user.userId;
    return this.walletsService.getWalletByUserId(userId);
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
    const userId = req.user.id || req.user.userId;
    return this.walletsService.getWalletTransactions(userId, page, limit);
  }

  /**
   * Calculate usable wallet breakdown for a booking according to dynamic SystemConfig rules.
   */
  @Get('usable')
  async getUsableWallet(
    @Req() req: any,
    @Query('bookingAmount') bookingAmount: string,
    @Query('requestedAmount') requestedAmount?: string,
  ) {
    const userId = req.user.id || req.user.userId;
    const parsedBookingAmount = parseFloat(bookingAmount) || 0;
    const parsedRequested = requestedAmount ? parseFloat(requestedAmount) : undefined;
    return this.walletsService.validateAndCalculateUsableWallet(
      userId,
      parsedBookingAmount,
      parsedRequested,
    );
  }

  /**
   * Create Razorpay order to add money to wallet.
   */
  @Post('deposit/create-order')
  async createDepositOrder(
    @Req() req: any,
    @Body() dto: CreateDepositOrderDto,
  ) {
    const userId = req.user.id || req.user.userId;
    return this.walletsService.createDepositOrder(userId, dto.amount);
  }

  /**
   * Verify Razorpay deposit payment and credit wallet.
   */
  @Post('deposit/verify')
  async verifyDeposit(
    @Req() req: any,
    @Body() dto: VerifyDepositDto,
  ) {
    const userId = req.user.id || req.user.userId;
    return this.walletsService.verifyDepositPayment(userId, dto);
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
    const userId = req.user.id || req.user.userId;
    return this.walletsService.adminAdjustWallet(userId, dto);
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
