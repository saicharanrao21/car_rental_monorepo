import { Controller, Get, Patch, Body, Param, Query, UseGuards, Req, ForbiddenException } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { UpdateMeDto } from './dto/update-me.dto';
import { UsersQueryDto } from './dto/users-query.dto';
import { BanUserDto } from './dto/ban-user.dto';
import { PaginationDto } from '../common/pagination.dto';
import { FcmTokenDto } from '../notifications/dto/fcm-token.dto';

@Controller('users')
@UseGuards(JwtAuthGuard, RolesGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Patch('me')
  async updateMe(@Req() req: any, @Body() dto: UpdateMeDto) {
    return this.usersService.updateMe(req.user.userId, dto);
  }

  @Patch('me/fcm-token')
  async updateFcmToken(@Req() req: any, @Body() dto: FcmTokenDto) {
    return this.usersService.updateFcmToken(req.user.userId, dto.token);
  }

  @Get()
  @Roles(Role.ADMIN)
  async findAll(@Query() query: UsersQueryDto) {
    return this.usersService.findAll(query);
  }

  @Get(':id')
  @Roles(Role.ADMIN)
  async findOne(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }

  @Get(':id/bookings')
  async findUserBookings(
    @Param('id') id: string,
    @Req() req: any,
    @Query() query: PaginationDto,
  ) {
    // ADMIN can access any user's bookings. Non-admins can only access their own.
    if (req.user.role !== Role.ADMIN && req.user.userId !== id) {
      throw new ForbiddenException('You are not authorized to view this user’s bookings.');
    }
    return this.usersService.findUserBookings(id, query);
  }

  @Patch(':id/ban')
  @Roles(Role.ADMIN)
  async banUser(@Param('id') id: string, @Body() dto: BanUserDto) {
    return this.usersService.banUser(id, dto);
  }
}
