import { IsArray, IsDateString, IsNotEmpty } from 'class-validator';

export class UpdateBlockedDatesDto {
  @IsNotEmpty()
  @IsArray()
  @IsDateString({}, { each: true, message: 'Each blocked date must be a valid ISO date string' })
  blockedDates: string[];
}
