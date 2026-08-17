import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
} from 'class-validator';
import { IncidentType, TicketPriority } from '@prisma/client';

export class CreateEmergencyDto {
  @IsString()
  @IsNotEmpty()
  bookingId: string;

  @IsEnum(IncidentType)
  @IsNotEmpty()
  incidentType: IncidentType;

  @IsEnum(TicketPriority)
  @IsOptional()
  urgency?: TicketPriority;

  @IsString()
  @IsOptional()
  customerNotes?: string;

  @IsNumber()
  @IsOptional()
  latitude?: number;

  @IsNumber()
  @IsOptional()
  longitude?: number;

  @IsString()
  @IsOptional()
  locationAddress?: string;
}
