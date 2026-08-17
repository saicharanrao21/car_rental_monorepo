import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import {
  EmergencyStatus,
  IncidentType,
  TicketPriority,
  EmergencyRequest,
  Role,
} from '@prisma/client';
import { CreateEmergencyDto } from './dto/create-emergency.dto';
import { UpdateEmergencyStatusDto } from './dto/update-emergency-status.dto';

@Injectable()
export class EmergencyAssistanceService {
  private readonly logger = new Logger(EmergencyAssistanceService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
    private readonly auditLogService: AuditLogService,
  ) {}

  /**
   * Generates sequential request number: SOS-YYYY-MM-XXXXX
   */
  private async generateRequestNumber(): Promise<string> {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const prefix = `SOS-${year}-${month}-`;

    const count = await this.prisma.emergencyRequest.count({
      where: {
        requestNumber: { startsWith: prefix },
      },
    });

    return `${prefix}${String(count + 1).padStart(5, '0')}`;
  }

  /**
   * Customer triggers an emergency SOS assistance request.
   */
  async createRequest(
    customerId: string,
    dto: CreateEmergencyDto,
  ): Promise<EmergencyRequest> {
    const booking = await this.prisma.booking.findUnique({
      where: { id: dto.bookingId },
      include: {
        car: true,
        vendor: true,
      },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    if (booking.customerId !== customerId) {
      throw new ForbiddenException(
        'Access denied: You do not own this booking.',
      );
    }

    // Duplicate SOS check: Cannot submit new SOS if an active one exists
    const activeSos = await this.prisma.emergencyRequest.findFirst({
      where: {
        bookingId: dto.bookingId,
        status: {
          in: [
            EmergencyStatus.REQUESTED,
            EmergencyStatus.ACKNOWLEDGED,
            EmergencyStatus.ASSIGNED,
            EmergencyStatus.PROVIDER_EN_ROUTE,
            EmergencyStatus.CUSTOMER_CONTACTED,
            EmergencyStatus.ON_SITE,
          ],
        },
      },
    });

    if (activeSos) {
      throw new ConflictException(
        `An active emergency assistance request #${activeSos.requestNumber} is already in progress.`,
      );
    }

    const requestNumber = await this.generateRequestNumber();

    const emergency = await this.prisma.emergencyRequest.create({
      data: {
        requestNumber,
        customerId,
        bookingId: booking.id,
        carId: booking.carId,
        vendorId: booking.vendorId,
        city: booking.vendor.city,
        incidentType: dto.incidentType,
        urgency: dto.urgency || TicketPriority.URGENT,
        status: EmergencyStatus.REQUESTED,
        customerNotes: dto.customerNotes || null,
        latitude: dto.latitude || null,
        longitude: dto.longitude || null,
        locationAddress: dto.locationAddress || booking.pickupLocation,
      },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        car: { select: { make: true, model: true, registrationNumber: true } },
        vendor: { select: { id: true, businessName: true, city: true } },
      },
    });

    // Notify customer confirmation
    await this.notificationsService.notifyUser(
      customerId,
      'Emergency Request Received',
      `Your emergency SOS request #${requestNumber} has been received. Our roadside support team is dispatching assistance immediately.`,
    );

    // Alert vendor if vendor has associated userId
    const vendorUser = await this.prisma.vendor.findUnique({
      where: { id: booking.vendorId },
      select: { userId: true },
    });
    if (vendorUser?.userId) {
      await this.notificationsService.notifyUser(
        vendorUser.userId,
        '🚨 Emergency Incident Alert',
        `An emergency (${dto.incidentType}) has been reported for vehicle ${booking.car.make} ${booking.car.model} (${booking.car.registrationNumber}).`,
      );
    }

    this.logger.warn(
      `🚨 Emergency SOS created: #${requestNumber} (${dto.incidentType}) for booking ${booking.id} in ${booking.vendor.city}`,
    );

    return emergency;
  }

  /**
   * Customer retrieves active emergency request for their booking.
   */
  async getActiveRequestForBooking(bookingId: string, customerId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
    });
    if (!booking || booking.customerId !== customerId) {
      throw new ForbiddenException('Access denied: Unauthorized booking access.');
    }

    return this.prisma.emergencyRequest.findFirst({
      where: { bookingId },
      orderBy: { createdAt: 'desc' },
      include: {
        car: { select: { make: true, model: true, registrationNumber: true } },
        vendor: { select: { businessName: true } },
      },
    });
  }

  /**
   * Customer retrieves all of their emergency requests.
   */
  async getMyRequests(customerId: string) {
    return this.prisma.emergencyRequest.findMany({
      where: { customerId },
      include: {
        car: { select: { make: true, model: true, registrationNumber: true } },
        vendor: { select: { businessName: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Vendor retrieves emergency requests for their own fleet.
   */
  async getVendorRequests(vendorUserId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId: vendorUserId },
    });
    if (!vendor) {
      throw new NotFoundException('Vendor profile not found.');
    }

    return this.prisma.emergencyRequest.findMany({
      where: { vendorId: vendor.id },
      include: {
        customer: { select: { name: true, phone: true } },
        car: { select: { make: true, model: true, registrationNumber: true } },
        booking: { select: { startDate: true, endDate: true, status: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Admin / Support Agent retrieves all emergency requests with city/status filters.
   */
  async getAllRequests(query: {
    status?: EmergencyStatus;
    incidentType?: IncidentType;
    city?: string;
    limit?: number;
    offset?: number;
  }) {
    const where: any = {};
    if (query.status) where.status = query.status;
    if (query.incidentType) where.incidentType = query.incidentType;
    if (query.city) where.city = query.city;

    const limit = query.limit || 50;
    const offset = query.offset || 0;

    const [requests, total] = await Promise.all([
      this.prisma.emergencyRequest.findMany({
        where,
        include: {
          customer: { select: { id: true, name: true, phone: true } },
          car: { select: { make: true, model: true, registrationNumber: true } },
          vendor: { select: { id: true, businessName: true, city: true } },
          booking: { select: { id: true, status: true, startDate: true, endDate: true } },
        },
        orderBy: [{ urgency: 'desc' }, { createdAt: 'desc' }],
        take: limit,
        skip: offset,
      }),
      this.prisma.emergencyRequest.count({ where }),
    ]);

    return { requests, total, limit, offset };
  }

  /**
   * Admin updates emergency request status and assigns provider/ETA.
   */
  async updateStatus(
    requestId: string,
    dto: UpdateEmergencyStatusDto,
    adminUserId: string,
  ): Promise<EmergencyRequest> {
    const request = await this.prisma.emergencyRequest.findUnique({
      where: { id: requestId },
    });

    if (!request) {
      throw new NotFoundException('Emergency request not found.');
    }

    const resolvedAt =
      dto.status === EmergencyStatus.RESOLVED && !request.resolvedAt
        ? new Date()
        : request.resolvedAt;

    const updated = await this.prisma.emergencyRequest.update({
      where: { id: requestId },
      data: {
        status: dto.status,
        assignedProviderName: dto.assignedProviderName ?? request.assignedProviderName,
        assignedProviderPhone: dto.assignedProviderPhone ?? request.assignedProviderPhone,
        contactNotes: dto.contactNotes ?? request.contactNotes,
        resolutionNotes: dto.resolutionNotes ?? request.resolutionNotes,
        estimatedEtaMinutes: dto.estimatedEtaMinutes ?? request.estimatedEtaMinutes,
        resolvedAt,
      },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        car: { select: { make: true, model: true, registrationNumber: true } },
      },
    });

    // Audit log
    await this.auditLogService.log(
      adminUserId,
      'EMERGENCY_STATUS_UPDATED',
      'EmergencyRequest',
      requestId,
      { previousStatus: request.status, newStatus: dto.status, provider: dto.assignedProviderName },
    );

    // Notify customer on status update
    let customerMessage = `Your emergency request status is now: ${dto.status}.`;
    if (dto.status === EmergencyStatus.ASSIGNED && dto.assignedProviderName) {
      customerMessage = `Assistance assigned: ${dto.assignedProviderName} (Phone: ${dto.assignedProviderPhone || 'N/A'}). ETA: ${dto.estimatedEtaMinutes || 30} mins.`;
    } else if (dto.status === EmergencyStatus.PROVIDER_EN_ROUTE) {
      customerMessage = `Roadside technician is en route to your vehicle.`;
    } else if (dto.status === EmergencyStatus.RESOLVED) {
      customerMessage = `Your roadside emergency request has been resolved. Drive safe!`;
    }

    await this.notificationsService.notifyUser(
      request.customerId,
      'Emergency Update',
      customerMessage,
    );

    return updated;
  }
}
