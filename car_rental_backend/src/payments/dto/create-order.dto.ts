import { IsString, IsNotEmpty, IsOptional, IsBoolean } from 'class-validator';

export class CreateOrderDto {
  @IsString()
  @IsNotEmpty()
  bookingId: string;

  @IsOptional()
  @IsBoolean()
  useWallet?: boolean;
}
