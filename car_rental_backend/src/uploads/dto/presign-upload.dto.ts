import { IsString, IsNotEmpty, IsIn } from 'class-validator';

export class PresignUploadDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(['car-photo', 'vendor-document', 'profile-photo', 'banner'])
  fileType: 'car-photo' | 'vendor-document' | 'profile-photo' | 'banner';

  @IsString()
  @IsNotEmpty()
  contentType: string;
}
