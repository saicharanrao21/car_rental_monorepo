import { IsEnum, IsString, IsNotEmpty, IsOptional } from 'class-validator';
import { DocumentType } from '@prisma/client';

export class CreateDocumentDto {
  @IsEnum(DocumentType)
  @IsNotEmpty()
  type: DocumentType;

  @IsString()
  @IsNotEmpty()
  fileUrl: string;

  @IsOptional()
  @IsString()
  carId?: string;
}
