import { BadRequestException } from '@nestjs/common';
import { AdminExportService } from '../admin-export.service';
import { AdminExportController } from '../admin-export.controller';
import { PrismaService } from '../../prisma/prisma.service';

describe('AdminExportService & AdminExportController', () => {
  let service: AdminExportService;
  let controller: AdminExportController;
  let prismaMock: any;

  beforeEach(() => {
    prismaMock = {
      booking: {
        findMany: jest.fn(),
      },
      payment: {
        findMany: jest.fn(),
      },
      vendor: {
        findMany: jest.fn(),
      },
    };

    service = new AdminExportService(prismaMock as unknown as PrismaService);
    controller = new AdminExportController(service);
  });

  describe('exportBookingsCsv', () => {
    it('should generate CSV with correct headers and escaped fields', async () => {
      prismaMock.booking.findMany.mockResolvedValue([
        {
          id: 'b1_test_id',
          customer: { name: 'John "The Driver" Doe', phone: '+919876543210', email: 'john@example.com' },
          vendor: { businessName: 'Speedy Rentals, LLC' },
          car: { make: 'Hyundai', model: 'Creta', registrationNumber: 'DL-01-AB-1234' },
          status: 'COMPLETED',
          totalFare: 4500,
          securityDeposit: { amount: 2000 },
          startDate: new Date('2026-09-01T10:00:00Z'),
          endDate: new Date('2026-09-03T10:00:00Z'),
          createdAt: new Date('2026-08-30T10:00:00Z'),
        },
      ]);

      const csv = await service.exportBookingsCsv();
      expect(csv).toContain('Booking ID,Reference Code,Customer Name');
      expect(csv).toContain('"John ""The Driver"" Doe"');
      expect(csv).toContain('"Speedy Rentals, LLC"');
      expect(csv).toContain('Hyundai Creta');
      expect(csv).toContain('4500');
    });

    it('should respect date filtering when provided', async () => {
      prismaMock.booking.findMany.mockResolvedValue([]);
      const start = new Date('2026-09-01');
      const end = new Date('2026-09-10');

      await service.exportBookingsCsv(start, end);

      expect(prismaMock.booking.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            createdAt: {
              gte: start,
              lte: end,
            },
          },
        }),
      );
    });
  });

  describe('exportPaymentsCsv', () => {
    it('should format payments data into CSV', async () => {
      prismaMock.payment.findMany.mockResolvedValue([
        {
          id: 'pay_1',
          bookingId: 'b1_test_id',
          booking: { id: 'b1_test_id' },
          razorpayOrderId: 'order_123',
          razorpayPaymentId: 'pay_123',
          amount: 5000,
          status: 'CAPTURED',
          refundStatus: 'NONE',
          paymentMethod: 'UPI',
          capturedAt: new Date('2026-09-01T11:00:00Z'),
          createdAt: new Date('2026-09-01T10:55:00Z'),
        },
      ]);

      const csv = await service.exportPaymentsCsv();
      expect(csv).toContain('Payment ID,Booking ID,Razorpay Order ID');
      expect(csv).toContain('pay_1,b1_test_id,order_123,pay_123,5000,CAPTURED,NONE,UPI');
    });
  });

  describe('exportVendorsCsv', () => {
    it('should format vendor data into CSV', async () => {
      prismaMock.vendor.findMany.mockResolvedValue([
        {
          id: 'v1',
          businessName: 'Apex Fleet',
          ownerName: 'Alice Smith',
          city: 'Bangalore',
          user: { phone: '+919999988888', email: 'alice@apex.com' },
          gstNumber: '29ABCDE1234F1Z5',
          verificationStatus: 'APPROVED',
          rating: 4.8,
          createdAt: new Date('2026-01-01T00:00:00Z'),
        },
      ]);

      const csv = await service.exportVendorsCsv();
      expect(csv).toContain('Vendor ID,Business Name,Owner Name');
      expect(csv).toContain('v1,Apex Fleet,Alice Smith,Bangalore,+919999988888');
    });
  });

  describe('exportData routing and validation', () => {
    it('should reject invalid start date', async () => {
      await expect(service.exportData('BOOKINGS', 'invalid-date')).rejects.toThrow(BadRequestException);
    });

    it('should reject invalid end date', async () => {
      await expect(service.exportData('BOOKINGS', undefined, 'invalid-date')).rejects.toThrow(BadRequestException);
    });

    it('should reject unsupported entity', async () => {
      await expect(service.exportData('UNKNOWN_ENTITY')).rejects.toThrow(BadRequestException);
    });

    it('should return filename and csv for valid BOOKINGS export', async () => {
      prismaMock.booking.findMany.mockResolvedValue([]);
      const res = await service.exportData('BOOKINGS');
      expect(res.filename).toMatch(/^drivego_bookings_\d{4}-\d{2}-\d{2}\.csv$/);
      expect(res.csv).toContain('Booking ID');
    });

    it('should return filename and csv for valid PAYMENTS export', async () => {
      prismaMock.payment.findMany.mockResolvedValue([]);
      const res = await service.exportData('PAYMENTS');
      expect(res.filename).toMatch(/^drivego_payments_\d{4}-\d{2}-\d{2}\.csv$/);
      expect(res.csv).toContain('Payment ID');
    });

    it('should return filename and csv for valid VENDORS export', async () => {
      prismaMock.vendor.findMany.mockResolvedValue([]);
      const res = await service.exportData('VENDORS');
      expect(res.filename).toMatch(/^drivego_vendors_\d{4}-\d{2}-\d{2}\.csv$/);
      expect(res.csv).toContain('Vendor ID');
    });
  });

  describe('AdminExportController', () => {
    it('should handle direct json return when res object is omitted', async () => {
      prismaMock.booking.findMany.mockResolvedValue([]);
      const result = await controller.exportCsv('BOOKINGS');
      expect(result).toHaveProperty('filename');
      expect(result).toHaveProperty('csv');
    });

    it('should set headers and stream CSV when Express response is provided', async () => {
      prismaMock.booking.findMany.mockResolvedValue([]);
      const resMock: any = {
        setHeader: jest.fn(),
        send: jest.fn((content) => content),
      };

      await controller.exportCsv('BOOKINGS', undefined, undefined, resMock);
      expect(resMock.setHeader).toHaveBeenCalledWith('Content-Type', 'text/csv');
      expect(resMock.setHeader).toHaveBeenCalledWith(
        'Content-Disposition',
        expect.stringContaining('attachment; filename='),
      );
      expect(resMock.send).toHaveBeenCalled();
    });
  });
});
