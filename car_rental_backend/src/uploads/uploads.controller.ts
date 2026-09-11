import {
  Controller,
  Post,
  Put,
  Get,
  Body,
  Param,
  UseGuards,
  Req,
  Res,
  NotFoundException,
  BadRequestException,
  HttpStatus,
} from '@nestjs/common';
import { UploadsService } from './uploads.service';
import { PresignUploadDto } from './dto/presign-upload.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RateLimit } from '../common/decorators/rate-limit.decorator';
import * as fs from 'fs';
import * as path from 'path';

@Controller('uploads')
export class UploadsController {
  private readonly storageDir = path.join(process.cwd(), 'uploads-storage');

  constructor(private readonly uploadsService: UploadsService) {}

  @RateLimit({ limit: 15, ttlSeconds: 60 })
  @Post('presign')
  @UseGuards(JwtAuthGuard)
  async presign(@Req() req: any, @Body() dto: PresignUploadDto) {
    return this.uploadsService.getPresignedUploadUrl(
      dto.fileType,
      dto.contentType,
      req.user.userId,
    );
  }

  // Local mock upload endpoint (only active in dev / mock mode)
  @Put('mock-put/:fileType/:userId/:filename')
  async mockUpload(
    @Param('fileType') fileType: string,
    @Param('userId') userId: string,
    @Param('filename') filename: string,
    @Req() req: any,
    @Res() res: any,
  ) {
    if (process.env.NODE_ENV === 'production') {
      throw new NotFoundException('Mock upload endpoint is disabled in production.');
    }
    if (fileType.includes('..') || userId.includes('..') || filename.includes('..')) {
      throw new BadRequestException('Invalid path traversal attempt.');
    }
    const safeFilename = path.basename(filename);
    const safeUserId = path.basename(userId);
    const safeFileType = path.basename(fileType);
    const dir = path.join(this.storageDir, safeFileType, safeUserId);
    if (!path.resolve(dir).startsWith(path.resolve(this.storageDir))) {
      throw new BadRequestException('Invalid path traversal attempt.');
    }
    fs.mkdirSync(dir, { recursive: true });

    const filePath = path.join(dir, safeFilename);
    const writeStream = fs.createWriteStream(filePath);

    req.pipe(writeStream);

    req.on('end', () => {
      res.status(HttpStatus.OK).send({ success: true });
    });

    req.on('error', (err: any) => {
      res.status(HttpStatus.INTERNAL_SERVER_ERROR).send({ error: err.message });
    });
  }

  // Local mock read endpoint (serves uploaded mock files)
  @Get('mock-files/:fileType/:userId/:filename')
  async serveMockFile(
    @Param('fileType') fileType: string,
    @Param('userId') userId: string,
    @Param('filename') filename: string,
    @Res() res: any,
  ) {
    if (process.env.NODE_ENV === 'production') {
      throw new NotFoundException('Mock file serving endpoint is disabled in production.');
    }
    if (fileType.includes('..') || userId.includes('..') || filename.includes('..')) {
      throw new BadRequestException('Invalid path traversal attempt.');
    }
    const safeFilename = path.basename(filename);
    const safeUserId = path.basename(userId);
    const safeFileType = path.basename(fileType);
    const filePath = path.join(this.storageDir, safeFileType, safeUserId, safeFilename);
    if (!path.resolve(filePath).startsWith(path.resolve(this.storageDir))) {
      throw new BadRequestException('Invalid path traversal attempt.');
    }

    if (!fs.existsSync(filePath)) {
      throw new NotFoundException('File not found');
    }

    const ext = path.extname(safeFilename).toLowerCase();
    let contentType = 'application/octet-stream';
    if (ext === '.jpg' || ext === '.jpeg') contentType = 'image/jpeg';
    else if (ext === '.png') contentType = 'image/png';
    else if (ext === '.webp') contentType = 'image/webp';
    else if (ext === '.pdf') contentType = 'application/pdf';

    res.setHeader('Content-Type', contentType);
    fs.createReadStream(filePath).pipe(res);
  }
}
