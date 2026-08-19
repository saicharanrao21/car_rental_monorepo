import 'package:shared_preferences/shared_preferences.dart';

abstract class OnboardingStorage {
  Future<bool> isOnboardingCompleted();
  Future<void> setOnboardingCompleted(bool completed);
  Future<void> clear();
}

class SharedPreferencesOnboardingStorage implements OnboardingStorage {
  static const String _onboardingCompletedKey = 'drivego_has_completed_onboarding';

  final SharedPreferences? _prefs;

  SharedPreferencesOnboardingStorage({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  @override
  Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(_onboardingCompletedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_onboardingCompletedKey, completed);
    } catch (_) {
      // Fail safely
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_onboardingCompletedKey);
    } catch (_) {
      // Fail safely
    }
  }
}
