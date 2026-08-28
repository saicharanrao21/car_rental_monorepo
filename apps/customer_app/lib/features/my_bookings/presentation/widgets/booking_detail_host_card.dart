import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:models/models.dart';
import '../../../support/presentation/pages/create_ticket_page.dart';

class BookingDetailHostCard extends StatelessWidget {
  final VendorModel? vendor;
  final String bookingId;
  final bool isConfirmed;

  const BookingDetailHostCard({
    super.key,
    required this.vendor,
    required this.bookingId,
    this.isConfirmed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (vendor == null) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final businessName = vendor!.businessName.isNotEmpty ? vendor!.businessName : 'Fleet Host';
    final city = vendor!.city;
    final rating = vendor!.rating;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.business_outlined, color: AppColors.primary, size: 24),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            businessName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vendor!.verificationStatus == 'verified' || vendor!.verificationStatus == 'VERIFIED') ...[
                          const Gap(6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 10, color: Colors.blue),
                                Gap(2),
                                Text(
                                  'VERIFIED',
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Gap(2),
                    Row(
                      children: [
                        if (rating > 0) ...[
                          const Icon(Icons.star, size: 13, color: Colors.amber),
                          const Gap(3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.bold),
                          ),
                          if (city.isNotEmpty) ...[
                            Text(' • ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            Text(city, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          ],
                        ] else if (city.isNotEmpty) ...[
                          Text(city, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(14),
          const Divider(height: 1),
          const Gap(10),
          if (isConfirmed)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.phone_outlined, size: 15),
                    label: const Text('Contact Host', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (vendor!.phone.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: vendor!.phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Host Contact: ${vendor!.phone} (Copied to clipboard)'),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Contact number is not available for this fleet host.'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.support_agent_outlined, size: 15),
                    label: const Text('Help & Support', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateTicketPage(initialBookingId: bookingId),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.support_agent_outlined, size: 15),
                    label: const Text('Help & Support', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateTicketPage(initialBookingId: bookingId),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
