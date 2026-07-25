import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'domain/repositories/wishlist_repository.dart';
import 'data/api_wishlist_repository.dart';
import '../../core/providers/api_providers.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiWishlistRepository(apiClient: apiClient);
});

final myWishlistCarsProvider = FutureProvider<List<CarModel>>((ref) async {
  final repo = ref.watch(wishlistRepositoryProvider);
  final cars = await repo.getMyWishlist();
  // Populate the wishlist IDs set
  ref.read(wishlistIdsProvider.notifier).setInitial(cars.map((c) => c.id).toSet());
  return cars;
});

class WishlistIdsNotifier extends StateNotifier<Set<String>> {
  final Ref ref;

  WishlistIdsNotifier(this.ref) : super({});

  void setInitial(Set<String> ids) {
    state = ids;
  }

  Future<void> toggle(String carId) async {
    final isWishlisted = state.contains(carId);
    final repo = ref.read(wishlistRepositoryProvider);

    // Optimistic state update
    if (isWishlisted) {
      state = {...state}..remove(carId);
      try {
        await repo.removeFromWishlist(carId);
      } catch (e) {
        // Rollback on error
        state = {...state, carId};
      }
    } else {
      state = {...state, carId};
      try {
        await repo.addToWishlist(carId);
      } catch (e) {
        // Rollback on error
        state = {...state}..remove(carId);
      }
    }

    ref.invalidate(myWishlistCarsProvider);
  }
}

final wishlistIdsProvider = StateNotifierProvider<WishlistIdsNotifier, Set<String>>((ref) {
  return WishlistIdsNotifier(ref);
});
