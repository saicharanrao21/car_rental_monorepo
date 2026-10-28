import { IsEnum, IsOptional, IsString } from 'class-validator';
import { PaginationDto } from '../../common/pagination.dto';
import { Role } from '@prisma/client';

export class UsersQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @IsEnum(Role)
  role?: Role;
}
