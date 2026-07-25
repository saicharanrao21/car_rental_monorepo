import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import '../../wishlist_providers.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(myWishlistCarsProvider);
    final wishlistedIds = ref.watch(wishlistIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Cars', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: wishlistAsync.when(
        data: (cars) {
          final activeCars = cars.where((c) => wishlistedIds.contains(c.id)).toList();
          if (activeCars.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  Gap(16),
                  Text('No Saved Cars Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Gap(8),
                  Text('Tap the heart icon on any car to save it for later.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeCars.length,
            itemBuilder: (context, index) {
              final car = activeCars[index];
              return CarCard(
                car: car,
                onTap: () => context.push('/car/${car.id}'),
                isWishlisted: true,
                onWishlistToggle: () {
                  ref.read(wishlistIdsProvider.notifier).toggle(car.id);
                },
              );
            },
          );
        },
        loading: () => const Center(child: AppLoader()),
        error: (err, stack) => Center(
          child: Text('Error loading saved cars: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}
