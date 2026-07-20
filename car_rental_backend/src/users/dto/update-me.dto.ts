import { IsEmail, IsOptional, IsString, IsUrl } from 'class-validator';

export class UpdateMeDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsEmail({}, { message: 'Must be a valid email address' })
  email?: string;

  @IsOptional()
  @IsUrl({}, { message: 'profilePhotoUrl must be a valid URL' })
  profilePhotoUrl?: string;
}
