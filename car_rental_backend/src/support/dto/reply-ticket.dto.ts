import { IsArray, IsBoolean, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class ReplyTicketDto {
  @IsString()
  @IsNotEmpty()
  message: string;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  attachments?: string[];

  @IsBoolean()
  @IsOptional()
  isInternal?: boolean;
}
