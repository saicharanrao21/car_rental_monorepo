import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class AddEvidenceDto {
  @IsNotEmpty()
  @IsString()
  fileUrl: string;

  @IsOptional()
  @IsString()
  description?: string;
}
