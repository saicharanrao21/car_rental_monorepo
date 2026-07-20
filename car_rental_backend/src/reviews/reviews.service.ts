import { 
  Injectable, 
  NotFoundException, 
  ForbiddenException, 
  BadRequestException, 
  ConflictException 
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { BookingStatus } from '@prisma/client';

@Injectable()
export class ReviewsService {
  constructor(private readonly prisma: PrismaService) {}

  async createReview(customerId: string, dto: CreateReviewDto) {
    return this.prisma.$transaction(async (tx) => {
      // 1. Find the booking
      const booking = await tx.booking.findUnique({
        where: { id: dto.bookingId },
      });

      if (!booking) {
        throw new NotFoundException('Booking not found.');
      }

      // 2. Verify booking belongs to this customer
      if (booking.customerId !== customerId) {
        throw new ForbiddenException('Access denied: You can only review your own bookings.');
      }

      // 3. Verify booking status is COMPLETED
      if (booking.status !== BookingStatus.COMPLETED) {
        throw new BadRequestException('You can only review completed bookings.');
      }

      // 4. Verify no review exists yet for this booking (Prisma unique constraint is a backstop)
      const existingReview = await tx.review.findUnique({
        where: { bookingId: dto.bookingId },
      });

      if (existingReview) {
        throw new ConflictException('A review has already been submitted for this booking.');
      }

      // 5. Create the review
      const review = await tx.review.create({
        data: {
          bookingId: dto.bookingId,
          customerId,
          vendorId: booking.vendorId,
          rating: dto.rating,
          comment: dto.comment,
        },
      });

      // 6. Recalculate vendor's average rating
      const ratingAggregate = await tx.review.aggregate({
        where: { vendorId: booking.vendorId },
        _avg: { rating: true },
      });

      const newAverageRating = ratingAggregate._avg.rating || 0;

      await tx.vendor.update({
        where: { id: booking.vendorId },
        data: { rating: newAverageRating },
      });

      return review;
    });
  }
}
