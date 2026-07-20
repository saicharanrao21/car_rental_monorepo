import { IsString, IsNotEmpty, IsNumber, IsPositive } from 'class-validator';

export class CreatePayoutDto {
  @IsString()
  @IsNotEmpty()
  vendorId: string;

  @IsNumber()
  @IsPositive()
  amount: number;
}
