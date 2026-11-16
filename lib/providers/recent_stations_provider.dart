import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myradio1/models/station.dart';

final recentStationsProvider = StateNotifierProvider<RecentStationsNotifier, List<Station>>((ref) {
  return RecentStationsNotifier();
});

class RecentStationsNotifier extends StateNotifier<List<Station>> {
  static const String _key = 'recent_stations_history';
  static const int _maxItems = 15;

  RecentStationsNotifier() : super([]) {
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_key);
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        if (mounted) {
          state = decoded
              .whereType<Map>()
              .map((item) => Station.fromMap(Map<String, dynamic>.from(item)))
              .toList();
        }
      }
    } catch (_) {
      // Ignore corrupt cache gracefully
    }
  }

  Future<void> addStation(Station station) async {
    final updated = [
      station,
      ...state.where((s) =>
          s.streamUrl != station.streamUrl &&
          !(s.id.isNotEmpty && s.id == station.id)),
    ].take(_maxItems).toList();

    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, json.encode(updated.map((s) => s.toMap()).toList()));
    } catch (_) {
      // Best-effort persistence
    }
  }

  Future<void> clearAll() async {
    state = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
