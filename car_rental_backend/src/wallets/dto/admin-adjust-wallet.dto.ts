import { IsString, IsNotEmpty, IsNumber, IsEnum, Min, IsOptional } from 'class-validator';
import { LedgerDirection, WalletBucketType } from '@prisma/client';

export class AdminAdjustWalletDto {
  @IsString()
  @IsNotEmpty()
  walletId: string;

  @IsNumber()
  @Min(1, { message: 'Adjustment amount must be at least ₹1' })
  amount: number;

  @IsEnum(LedgerDirection)
  direction: LedgerDirection; // CREDIT or DEBIT

  @IsEnum(WalletBucketType)
  bucket: WalletBucketType; // REAL_MONEY or PROMOTIONAL

  @IsString()
  @IsNotEmpty({ message: 'A mandatory audit reason is required for manual adjustments' })
  reason: string;

  @IsOptional()
  @IsString()
  clientNonce?: string;
}
