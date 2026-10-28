import { IsEmail, IsEnum, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';
import { StaffRole } from '../../auth/permissions.enum';

export class CreateStaffDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsEmail()
  email: string;

  @IsString()
  @IsNotEmpty()
  phone: string;

  @IsEnum(StaffRole)
  staffRole: StaffRole;

  @IsString()
  @MinLength(8)
  password: string;
}

