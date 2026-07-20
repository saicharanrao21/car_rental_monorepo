import { IsISO8601, IsNotEmpty } from 'class-validator';

export class DateRangeDto {
  @IsISO8601()
  @IsNotEmpty()
  startDate: string;

  @IsISO8601()
  @IsNotEmpty()
  endDate: string;
}
