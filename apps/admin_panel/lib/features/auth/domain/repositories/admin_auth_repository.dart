abstract interface class AdminAuthRepository {
  Future<bool> login(String email, String password);
}
