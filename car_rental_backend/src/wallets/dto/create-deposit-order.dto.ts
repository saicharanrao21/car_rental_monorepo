import { IsNumber, Min, Max } from 'class-validator';

export class CreateDepositOrderDto {
  @IsNumber()
  @Min(100, { message: 'Minimum wallet deposit is ₹100' })
  @Max(50000, { message: 'Maximum single wallet deposit is ₹50,000' })
  amount: number;
}
