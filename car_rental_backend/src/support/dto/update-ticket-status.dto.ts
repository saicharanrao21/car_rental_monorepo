import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { TicketPriority, TicketStatus } from '@prisma/client';

export class UpdateTicketStatusDto {
  @IsEnum(TicketStatus)
  @IsNotEmpty()
  status: TicketStatus;

  @IsEnum(TicketPriority)
  @IsOptional()
  priority?: TicketPriority;

  @IsString()
  @IsOptional()
  assignedToUserId?: string;

  @IsString()
  @IsOptional()
  resolutionNote?: string;
}
