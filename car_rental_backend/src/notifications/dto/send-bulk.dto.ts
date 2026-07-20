import { IsNotEmpty, IsString } from 'class-validator';

export class SendBulkDto {
  @IsString()
  @IsNotEmpty()
  target: string;

  @IsString()
  @IsNotEmpty()
  title: string;

  @IsString()
  @IsNotEmpty()
  body: string;
}
