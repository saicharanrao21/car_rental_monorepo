import { IsString, IsOptional } from 'class-validator';

export class MarkPaidDto {
  @IsString()
  @IsOptional()
  note?: string;
}
