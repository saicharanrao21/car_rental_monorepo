import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class DisputeClaimDto {
  @IsString()
  @IsNotEmpty()
  @MinLength(10)
  customerDispute: string;
}
