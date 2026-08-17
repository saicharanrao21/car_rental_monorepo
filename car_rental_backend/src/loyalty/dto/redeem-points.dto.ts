import { IsInt, IsNotEmpty, IsOptional, IsString, Min } from 'class-validator';

export class RedeemPointsDto {
  @IsInt()
  @Min(2, { message: 'Minimum 2 points required for redemption (2 points = ₹1)' })
  @IsNotEmpty()
  points: number;

  @IsString()
  @IsOptional()
  idempotencyKey?: string;
}
