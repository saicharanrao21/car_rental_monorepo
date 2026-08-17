import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { EmergencyAssistanceService } from './emergency-assistance.service';
import { CreateEmergencyDto } from './dto/create-emergency.dto';
import { UpdateEmergencyStatusDto } from './dto/update-emergency-status.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role, EmergencyStatus, IncidentType } from '@prisma/client';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class EmergencyAssistanceController {
  constructor(private readonly emergencyService: EmergencyAssistanceService) {}

  /**
   * Customer triggers an emergency SOS request for an active booking.
   */
  @Post('emergency/requests')
  @Roles(Role.CUSTOMER)
  async createRequest(@Request() req: any, @Body() dto: CreateEmergencyDto) {
    return this.emergencyService.createRequest(req.user.userId, dto);
  }

  /**
   * Customer retrieves all of their emergency requests.
   */
  @Get('emergency/requests/my')
  @Roles(Role.CUSTOMER)
  async getMyRequests(@Request() req: any) {
    return this.emergencyService.getMyRequests(req.user.userId);
  }

  /**
   * Customer gets active emergency request for a booking.
   */
  @Get('emergency/requests/booking/:bookingId')
  @Roles(Role.CUSTOMER)
  async getActiveRequestForBooking(
    @Request() req: any,
    @Param('bookingId') bookingId: string,
  ) {
    return this.emergencyService.getActiveRequestForBooking(
      bookingId,
      req.user.userId,
    );
  }

  /**
   * Vendor retrieves emergency requests for their vehicles.
   */
  @Get('vendor/emergency/requests')
  @Roles(Role.VENDOR)
  async getVendorRequests(@Request() req: any) {
    return this.emergencyService.getVendorRequests(req.user.userId);
  }

  /**
   * Admin / Support Agent retrieves all emergency requests.
   */
  @Get('admin/emergency/requests')
  @Roles(Role.SUPPORT_AGENT, Role.ADMIN)
  async getAllRequests(
    @Query('status') status?: EmergencyStatus,
    @Query('incidentType') incidentType?: IncidentType,
    @Query('city') city?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.emergencyService.getAllRequests({
      status,
      incidentType,
      city,
      limit: limit ? parseInt(limit, 10) : undefined,
      offset: offset ? parseInt(offset, 10) : undefined,
    });
  }

  /**
   * Admin / Support Agent updates emergency status and assigns provider/ETA.
   */
  @Patch('admin/emergency/requests/:id/status')
  @Roles(Role.SUPPORT_AGENT, Role.ADMIN)
  async updateStatus(
    @Request() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateEmergencyStatusDto,
  ) {
    return this.emergencyService.updateStatus(id, dto, req.user.userId);
  }
}
