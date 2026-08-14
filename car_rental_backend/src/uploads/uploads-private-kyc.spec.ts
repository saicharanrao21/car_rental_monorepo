import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { UploadsService } from './uploads.service';
import { VendorsService } from '../vendors/vendors.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { BankEncryptionService } from '../common/bank-encryption.service';

describe('Phase 4C: Private KYC Document Storage & Access Control', () => {
  describe('UploadsService Private KYC Hardening', () => {
    let configService: ConfigService;

    beforeEach(() => {
      configService = new ConfigService({
        NODE_ENV: 'test',
        R2_USE_MOCK: 'true',
        R2_BUCKET_NAME: 'drivego-uploads',
        R2_PUBLIC_URL: 'https://pub-cdn.drivego.in',
      });
    });

    it('should NOT generate a public URL for private vendor-document uploads', async () => {
      const service = new UploadsService(configService);
      const res = await service.getPresignedUploadUrl(
        'vendor-document',
        'application/pdf',
        'user_123',
      );

      expect(res.uploadUrl).toBeDefined();
      expect(res.publicUrl).toBeNull();
      expect(res.key).toMatch(/^vendor-document\/user_123\/[a-f0-9-]+\.pdf$/);
    });

    it('should generate a public URL for public car-photo uploads', async () => {
      const service = new UploadsService(configService);
      const res = await service.getPresignedUploadUrl(
        'car-photo',
        'image/jpeg',
        'user_123',
      );

      expect(res.uploadUrl).toBeDefined();
      expect(res.publicUrl).toBeDefined();
      expect(res.publicUrl).toContain('mock-files/car-photo/user_123/');
      expect(res.key).toMatch(/^car-photo\/user_123\/[a-f0-9-]+\.jpg$/);
    });

    it('should generate presigned download URL from relative key', async () => {
      const service = new UploadsService(configService);
      const downloadUrl = await service.getPresignedDownloadUrl(
        'vendor-document/user_123/doc.pdf',
        900,
      );

      expect(downloadUrl).toBe(
        'http://localhost:3000/uploads/mock-files/vendor-document/user_123/doc.pdf',
      );
    });

    it('should extract relative key and generate presigned download URL from legacy full URL', async () => {
      const service = new UploadsService(configService);
      const downloadUrl = await service.getPresignedDownloadUrl(
        'https://pub-cdn.drivego.in/vendor-document/user_123/doc.pdf',
        900,
      );

      expect(downloadUrl).toBe(
        'http://localhost:3000/uploads/mock-files/vendor-document/user_123/doc.pdf',
      );
    });

    it('should reject invalid MIME types', async () => {
      const service = new UploadsService(configService);
      await expect(
        service.getPresignedUploadUrl(
          'vendor-document',
          'application/x-executable',
          'user_123',
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('VendorsService Document Security & Anti-IDOR', () => {
    let vendorsService: VendorsService;
    let prisma: any;
    let uploadsService: UploadsService;

    beforeEach(() => {
      prisma = {
        vendor: {
          findUnique: jest.fn(),
          findMany: jest.fn(),
        },
        document: {
          create: jest.fn(),
          findMany: jest.fn(),
          findUnique: jest.fn(),
          update: jest.fn(),
        },
        car: {
          findUnique: jest.fn(),
        },
      };

      const configService = new ConfigService({
        NODE_ENV: 'test',
        R2_USE_MOCK: 'true',
        BANK_ENCRYPTION_KEY: 'test_encryption_key_at_least_32_characters_long!',
      });

      uploadsService = new UploadsService(configService);
      const bankEncryption = new BankEncryptionService(configService);

      vendorsService = new VendorsService(
        prisma,
        {} as NotificationsService,
        {} as AuditLogService,
        bankEncryption,
        uploadsService,
      );
    });

    it('should successfully add document when key matches authenticated user namespace', async () => {
      prisma.vendor.findUnique.mockResolvedValue({
        id: 'vendor_abc',
        userId: 'user_123',
      });

      prisma.document.create.mockImplementation(({ data }: any) => ({
        id: 'doc_1',
        ...data,
      }));

      const res = await vendorsService.addDocument(
        'user_123',
        'TRADE_LICENSE',
        'vendor-document/user_123/uuid-123.pdf',
      );

      expect(res.vendorId).toBe('vendor_abc');
      expect(res.fileUrl).toBe('vendor-document/user_123/uuid-123.pdf');
    });

    it('should reject addDocument when key belongs to another user (anti-IDOR)', async () => {
      prisma.vendor.findUnique.mockResolvedValue({
        id: 'vendor_abc',
        userId: 'user_123',
      });

      await expect(
        vendorsService.addDocument(
          'user_123',
          'TRADE_LICENSE',
          'vendor-document/victim_user_999/private-tax.pdf',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should return presigned download URLs when vendor retrieves own documents', async () => {
      prisma.vendor.findUnique.mockResolvedValue({
        id: 'vendor_abc',
        userId: 'user_123',
      });

      prisma.document.findMany.mockResolvedValue([
        {
          id: 'doc_1',
          vendorId: 'vendor_abc',
          carId: null,
          type: 'TRADE_LICENSE',
          fileUrl: 'vendor-document/user_123/doc1.pdf',
          status: 'VERIFIED',
          uploadedAt: new Date(),
        },
      ]);

      const docs = await vendorsService.getDocuments('user_123');

      expect(docs).toHaveLength(1);
      expect(docs[0].fileUrl).toContain(
        'mock-files/vendor-document/user_123/doc1.pdf',
      );
    });

    it('should return presigned download URLs when admin retrieves vendor documents', async () => {
      prisma.vendor.findUnique.mockResolvedValue({
        id: 'vendor_target',
        userId: 'user_456',
      });

      prisma.document.findMany.mockResolvedValue([
        {
          id: 'doc_2',
          vendorId: 'vendor_target',
          carId: null,
          type: 'RC_BOOK',
          fileUrl: 'https://pub-cdn.drivego.in/vendor-document/user_456/rc.pdf',
          status: 'PENDING',
          uploadedAt: new Date(),
        },
      ]);

      const docs = await vendorsService.getDocumentsForAdmin('vendor_target');

      expect(docs).toHaveLength(1);
      expect(docs[0].fileUrl).toContain(
        'mock-files/vendor-document/user_456/rc.pdf',
      );
    });

    it('should throw NotFoundException if admin queries documents for nonexistent vendor', async () => {
      prisma.vendor.findUnique.mockResolvedValue(null);

      await expect(
        vendorsService.getDocumentsForAdmin('nonexistent_vendor'),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
