import { IsInt, IsNotEmpty, IsString, MaxLength, MinLength } from 'class-validator';

export class AdminAdjustLoyaltyDto {
  @IsString()
  @IsNotEmpty()
  userId: string;

  @IsInt()
  @IsNotEmpty()
  points: number;

  @IsString()
  @MinLength(5, { message: 'Reason must be at least 5 characters long' })
  @MaxLength(500)
  @IsNotEmpty()
  reason: string;

  @IsString()
  @IsNotEmpty()
  idempotencyKey: string;
}
