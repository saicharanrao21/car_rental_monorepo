import { IsEnum, IsNotEmpty } from 'class-validator';
import { DocumentStatus } from '@prisma/client';

export class UpdateDocumentStatusDto {
  @IsEnum(DocumentStatus)
  @IsNotEmpty()
  status: DocumentStatus;
}
