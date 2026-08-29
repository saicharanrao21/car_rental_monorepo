import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
} from 'class-validator';
import { LedgerDirection } from '@prisma/client';

export class CreateFinancialAdjustmentDto {
  @IsNotEmpty()
  @IsString()
  targetType: 'VENDOR' | 'CUSTOMER_WALLET' | 'BOOKING' | 'SECURITY_DEPOSIT';

  @IsNotEmpty()
  @IsString()
  targetId: string;

  @IsNotEmpty()
  @IsNumber()
  @IsPositive()
  amount: number;

  @IsNotEmpty()
  @IsEnum(LedgerDirection)
  direction: LedgerDirection; // CREDIT, DEBIT

  @IsNotEmpty()
  @IsString()
  reason: string;

  @IsNotEmpty()
  @IsString()
  category: string; // DAMAGE_COMPENSATION, DISPUTE_SETTLEMENT, GOODWILL, COMMISSION_CORRECTION, PENALTY_WAIVER

  @IsOptional()
  @IsString()
  referenceId?: string;

  @IsNotEmpty()
  @IsString()
  idempotencyKey: string;

  @IsOptional()
  metadata?: any;
}
