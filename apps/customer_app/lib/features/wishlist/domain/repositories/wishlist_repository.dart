import 'package:models/models.dart';

abstract class WishlistRepository {
  Future<void> addToWishlist(String carId);
  Future<void> removeFromWishlist(String carId);
  Future<List<CarModel>> getMyWishlist();
}
