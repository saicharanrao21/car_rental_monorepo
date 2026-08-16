import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
  Request,
} from '@nestjs/common';
import { AdditionalDriversService } from './additional-drivers.service';
import { AddDriverDto } from './dto/add-driver.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';

@Controller('bookings/:id/additional-drivers')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdditionalDriversController {
  constructor(
    private readonly additionalDriversService: AdditionalDriversService,
  ) {}

  @Post()
  async addDriver(
    @Param('id') bookingId: string,
    @Body() dto: AddDriverDto,
    @Request() req: any,
  ) {
    return this.additionalDriversService.addDriver(bookingId, dto, req.user);
  }

  @Get()
  async getDrivers(@Param('id') bookingId: string) {
    return this.additionalDriversService.getDriversForBooking(bookingId);
  }
}

@Controller('admin/additional-drivers')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN, Role.SUPPORT_AGENT)
export class AdminAdditionalDriversController {
  constructor(
    private readonly additionalDriversService: AdditionalDriversService,
  ) {}

  @Post(':id/verify')
  async verifyDriver(
    @Param('id') driverId: string,
    @Body('isApproved') isApproved: boolean,
    @Body('rejectionReason') rejectionReason: string,
    @Request() req: any,
  ) {
    return this.additionalDriversService.verifyDriver(
      driverId,
      isApproved,
      rejectionReason,
      req.user.userId,
    );
  }
}
