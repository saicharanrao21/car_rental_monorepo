import {
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsArray,
} from 'class-validator';
import { TicketCategory, TicketPriority } from '@prisma/client';

export class CreateTicketDto {
  @IsEnum(TicketCategory)
  @IsNotEmpty()
  category: TicketCategory;

  @IsEnum(TicketPriority)
  @IsOptional()
  priority?: TicketPriority;

  @IsString()
  @IsNotEmpty()
  subject: string;

  @IsString()
  @IsNotEmpty()
  description: string;

  @IsString()
  @IsOptional()
  bookingId?: string;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  attachments?: string[];
}
