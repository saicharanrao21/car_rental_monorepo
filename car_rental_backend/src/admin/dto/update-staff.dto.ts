import { IsBoolean, IsEnum, IsOptional, IsString } from 'class-validator';
import { StaffRole } from '../../auth/permissions.enum';

export class UpdateStaffDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsEnum(StaffRole)
  staffRole?: StaffRole;

  @IsOptional()
  @IsBoolean()
  banned?: boolean;

  @IsOptional()
  @IsString()
  password?: string;
}
