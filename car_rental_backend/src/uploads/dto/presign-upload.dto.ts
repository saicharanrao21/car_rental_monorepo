import { IsString, IsNotEmpty, IsIn } from 'class-validator';

export class PresignUploadDto {
  @IsString()
  @IsNotEmpty()
  @IsIn([
    'car-photo',
    'vendor-document',
    'profile-photo',
    'banner',
    'inspection-photo',
  ])
  fileType:
    | 'car-photo'
    | 'vendor-document'
    | 'profile-photo'
    | 'banner'
    | 'inspection-photo';

  @IsString()
  @IsNotEmpty()
  contentType: string;
}
