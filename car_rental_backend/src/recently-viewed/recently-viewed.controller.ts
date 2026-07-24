import { Controller, Get, Post, Body, UseGuards, Req } from '@nestjs/common';
import { RecentlyViewedService } from './recently-viewed.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('recently-viewed')
@UseGuards(JwtAuthGuard)
export class RecentlyViewedController {
  constructor(private readonly recentlyViewedService: RecentlyViewedService) {}

  @Post()
  async recordView(@Req() req: any, @Body('carId') carId: string) {
    return this.recentlyViewedService.recordView(req.user.userId, carId);
  }

  @Get('me')
  async getMyRecentlyViewed(@Req() req: any) {
    return this.recentlyViewedService.getMyRecentlyViewed(req.user.userId);
  }
}
