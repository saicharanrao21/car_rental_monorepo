import { IsEnum, IsString, IsNotEmpty, IsOptional, IsDateString } from 'class-validator';
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

  @IsOptional()
  @IsDateString()
  expiresAt?: string;
}

