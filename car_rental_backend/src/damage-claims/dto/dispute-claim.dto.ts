import { IsNotEmpty, IsOptional, IsString, MinLength, IsArray } from 'class-validator';

export class DisputeClaimDto {
  @IsString()
  @IsNotEmpty()
  @MinLength(10)
  customerDispute: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  disputePhotos?: string[];
}
