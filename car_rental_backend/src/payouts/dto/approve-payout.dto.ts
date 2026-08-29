import { IsOptional, IsString } from 'class-validator';

export class ApprovePayoutDto {
  @IsOptional()
  @IsString()
  adminNotes?: string;
}
