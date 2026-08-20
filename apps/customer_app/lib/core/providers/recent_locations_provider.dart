import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kRecentLocationsKey = 'drivego_recent_locations';

class RecentLocationsNotifier extends StateNotifier<List<String>> {
  RecentLocationsNotifier() : super(const []) {
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecentLocationsKey) ?? [];
    state = list;
  }

  Future<void> addLocation(String location) async {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return;

    final updated = [trimmed, ...state.where((e) => e != trimmed)].take(5).toList();
    state = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentLocationsKey, updated);
  }

  Future<void> clearRecents() async {
    state = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentLocationsKey);
  }
}

final recentLocationsProvider = StateNotifierProvider<RecentLocationsNotifier, List<String>>((ref) {
  return RecentLocationsNotifier();
});
