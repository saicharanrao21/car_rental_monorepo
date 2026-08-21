import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/core.dart';
import '../../domain/repositories/my_bookings_repository.dart';
import '../../../emergency/presentation/widgets/emergency_bottom_sheet.dart';

class ActiveTripHeroCard extends StatelessWidget {
  final CustomerBookingItem item;
  final VoidCallback? onRefresh;

  const ActiveTripHeroCard({
    super.key,
    required this.item,
    this.onRefresh,
  });

  String _formatRemainingTime(DateTime endDate) {
    final now = DateTime.now();
    final diff = endDate.difference(now);
    if (diff.isNegative) {
      return 'Trip ended • Return pending';
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    if (days > 0) {
      return '$days day${days > 1 ? "s" : ""} $hours hr${hours > 1 ? "s" : ""} remaining';
    } else if (hours > 0) {
      return '$hours hr${hours > 1 ? "s" : ""} $minutes min remaining';
    } else {
      return '$minutes minutes remaining';
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = item.booking;
    final car = item.car;
    final vendor = item.vendor;
    final photoUrl = car?.photos.isNotEmpty == true ? car!.photos.first : null;
    final remainingText = _formatRemainingTime(booking.endDate);
    final status = booking.status.toLowerCase();
    final isHandoverReady = status == 'handover_ready';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHandoverReady
              ? [const Color(0xFF8D5B00), const Color(0xFFD97706)]
              : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isHandoverReady ? Colors.amber : Colors.blueGrey).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/bookings/${booking.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Live Badge & Countdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isHandoverReady ? Colors.white : Colors.greenAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isHandoverReady ? Colors.amber[800]! : Colors.greenAccent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isHandoverReady ? Colors.amber[900] : Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const Gap(6),
                            Flexible(
                              child: Text(
                                isHandoverReady ? 'HANDOVER READY' : 'ACTIVE TRIP IN PROGRESS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isHandoverReady ? Colors.amber[950] : Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(8),
                    Text(
                      remainingText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const Gap(14),

                // Vehicle Info + Photo Row
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 76,
                        height: 56,
                        color: Colors.white12,
                        child: photoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Icon(
                                  Icons.directions_car,
                                  color: Colors.white70,
                                ),
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.directions_car,
                                  color: Colors.white70,
                                ),
                              )
                            : const Icon(
                                Icons.directions_car,
                                color: Colors.white70,
                              ),
                      ),
                    ),
                    const Gap(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car != null ? '${car.make} ${car.model}' : '${booking.tripType} Booking',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Gap(2),
                          Text(
                            vendor != null ? 'Host: ${vendor.businessName}' : 'DriveGo Verified Fleet',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Gap(4),
                          Text(
                            'Return: ${booking.endDate.toDDMMYYYY()} • ${booking.dropLocation ?? booking.pickupLocation}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(16),

                // Quick Action Bar
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.navigation_outlined, size: 16),
                        label: const Text('Manage Trip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => context.push('/bookings/${booking.id}'),
                      ),
                    ),
                    const Gap(10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.emergency_outlined, color: Colors.redAccent, size: 16),
                      label: const Text('SOS', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final dispatched = await EmergencyBottomSheet.show(
                          context,
                          bookingId: booking.id,
                          carDetails: car != null ? '${car.make} ${car.model} (${car.registrationNumber})' : booking.tripType,
                        );
                        if (dispatched == true && onRefresh != null) {
                          onRefresh!();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
