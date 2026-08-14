import { IsNotEmpty, IsNumber, IsPositive, IsString } from 'class-validator';

export class CreateDepositDto {
  @IsString()
  @IsNotEmpty()
  bookingId: string;

  @IsNumber()
  @IsPositive()
  amount: number;
}
