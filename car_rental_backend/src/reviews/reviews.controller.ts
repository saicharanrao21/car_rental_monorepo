import { Controller, Post, Body, UseGuards, Req } from '@nestjs/common';
import { ReviewsService } from './reviews.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { RateLimit } from '../common/decorators/rate-limit.decorator';

@Controller('reviews')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @RateLimit({ limit: 5, ttlSeconds: 60 })
  @Post()
  @Roles(Role.CUSTOMER)
  async createReview(@Req() req: any, @Body() dto: CreateReviewDto) {
    return this.reviewsService.createReview(req.user.userId, dto);
  }
}
