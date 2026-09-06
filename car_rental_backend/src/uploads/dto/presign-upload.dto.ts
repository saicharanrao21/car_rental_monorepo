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
    'damage-claim',
  ])
  fileType:
    | 'car-photo'
    | 'vendor-document'
    | 'profile-photo'
    | 'banner'
    | 'inspection-photo'
    | 'damage-claim';

  @IsString()
  @IsNotEmpty()
  contentType: string;
}
