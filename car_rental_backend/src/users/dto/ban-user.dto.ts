import { IsBoolean, IsNotEmpty } from 'class-validator';

export class BanUserDto {
  @IsNotEmpty()
  @IsBoolean()
  banned: boolean;
}
