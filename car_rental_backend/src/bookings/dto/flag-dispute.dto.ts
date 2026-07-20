import { IsString, IsNotEmpty } from 'class-validator';

export class FlagDisputeDto {
  @IsString()
  @IsNotEmpty()
  note: string;
}
