import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import * as crypto from 'crypto';

@Injectable()
export class UploadsService {
  private readonly s3Client: S3Client | null = null;
  private readonly useMock: boolean;
  private readonly bucketName: string;
  private readonly publicUrl: string;

  constructor(private readonly configService: ConfigService) {
    this.useMock = this.configService.get<string>('R2_USE_MOCK') === 'true';
    this.bucketName = this.configService.get<string>('R2_BUCKET_NAME') || 'drivego-uploads';
    this.publicUrl = this.configService.get<string>('R2_PUBLIC_URL') || 'https://pub-placeholder.r2.dev';

    if (!this.useMock) {
      const endpoint = this.configService.get<string>('R2_ENDPOINT');
      const accessKeyId = this.configService.get<string>('R2_ACCESS_KEY_ID');
      const secretAccessKey = this.configService.get<string>('R2_SECRET_ACCESS_KEY');

      if (!endpoint || !accessKeyId || !secretAccessKey) {
        throw new Error('Cloudflare R2 keys are required when R2_USE_MOCK is false.');
      }

      this.s3Client = new S3Client({
        region: 'auto',
        endpoint,
        credentials: {
          accessKeyId,
          secretAccessKey,
        },
      });
    }
  }

  async getPresignedUploadUrl(
    fileType: 'car-photo' | 'vendor-document' | 'profile-photo' | 'banner',
    contentType: string,
    userId: string,
  ) {
    const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
    if (!allowedMimeTypes.includes(contentType)) {
      throw new BadRequestException('Invalid contentType. Allowed types: image/jpeg, image/png, image/webp, application/pdf.');
    }

    let ext = 'bin';
    if (contentType === 'image/jpeg') ext = 'jpg';
    else if (contentType === 'image/png') ext = 'png';
    else if (contentType === 'image/webp') ext = 'webp';
    else if (contentType === 'application/pdf') ext = 'pdf';

    const filename = `${crypto.randomUUID()}.${ext}`;
    const key = `${fileType}/${userId}/${filename}`;

    if (this.useMock) {
      // In local dev mock mode, return local endpoints for upload/read simulation
      const uploadUrl = `http://localhost:3000/uploads/mock-put/${fileType}/${userId}/${filename}`;
      const publicUrl = `http://localhost:3000/uploads/mock-files/${fileType}/${userId}/${filename}`;

      return {
        uploadUrl,
        publicUrl,
        key,
      };
    }

    const command = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: key,
      ContentType: contentType,
    });

    try {
      const uploadUrl = await getSignedUrl(this.s3Client!, command, { expiresIn: 300 });
      const publicUrl = `${this.publicUrl}/${key}`;

      return {
        uploadUrl,
        publicUrl,
        key,
      };
    } catch (err) {
      throw new BadRequestException('Failed to generate presigned upload URL with R2');
    }
  }
}
