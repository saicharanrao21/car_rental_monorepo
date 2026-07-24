import { Controller, Get, Post, Delete, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { WishlistService } from './wishlist.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PaginationDto } from '../common/pagination.dto';

@Controller('wishlist')
@UseGuards(JwtAuthGuard)
export class WishlistController {
  constructor(private readonly wishlistService: WishlistService) {}

  @Post()
  async addToWishlist(@Req() req: any, @Body('carId') carId: string) {
    return this.wishlistService.toggleWishlist(req.user.userId, carId);
  }

  @Delete(':carId')
  async removeFromWishlist(@Req() req: any, @Param('carId') carId: string) {
    return this.wishlistService.removeFromWishlist(req.user.userId, carId);
  }

  @Get('me')
  async getMyWishlist(@Req() req: any, @Query() pagination: PaginationDto) {
    return this.wishlistService.getMyWishlist(req.user.userId, pagination);
  }
}
