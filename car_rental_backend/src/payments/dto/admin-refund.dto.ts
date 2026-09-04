import { IsNotEmpty, IsString, IsOptional, IsNumber, Min, MinLength } from 'class-validator';

export class AdminRefundDto {
  @IsOptional()
  @IsNumber()
  @Min(100) // Minimum 1 INR (100 paise)
  amountInPaise?: number;

  @IsString()
  @IsNotEmpty()
  @MinLength(10, { message: 'Reason must be at least 10 characters for audit compliance' })
  reason: string;

  @IsOptional()
  @IsString()
  idempotencyKey?: string;
}
