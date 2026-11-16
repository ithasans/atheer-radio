import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myradio1/models/station.dart';

// Backwards compatibility alias
typedef RadioStation = Station;

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<Station>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<List<Station>> {
  FavoritesNotifier() : super([]) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favsJson = prefs.getString('favorite_stations');
    if (favsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(favsJson);
        if (mounted) {
          state = decoded.map((item) => Station.fromMap(Map<String, dynamic>.from(item as Map))).toList();
        }
      } catch (_) {
        if (mounted) state = [];
      }
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('favorite_stations', json.encode(state.map((s) => s.toMap()).toList()));
    } catch (_) {}
  }

  bool isFavorite(Station station) {
    return state.any((s) => s.streamUrl == station.streamUrl || (s.id.isNotEmpty && s.id == station.id));
  }

  Future<void> toggleFavorite(Station station) async {
    final exists = isFavorite(station);
    if (exists) {
      state = state.where((s) => s.streamUrl != station.streamUrl && s.id != station.id).toList();
    } else {
      state = [...state, station];
    }
    await _persist();
  }

  String exportFavoritesJson() {
    return const JsonEncoder.withIndent('  ').convert(
      state.map((s) => s.toMap()).toList(),
    );
  }

  /// Imports favorites from JSON backup text without duplicating existing streams.
  /// Returns the number of newly added stations, or -1 if JSON format is invalid.
  Future<int> importFavoritesJson(String rawJson) async {
    try {
      final dynamic decoded = json.decode(rawJson.trim());
      if (decoded is! List) return -1;

      final List<Station> incoming = [];
      for (final item in decoded) {
        if (item is Map) {
          final station = Station.fromMap(Map<String, dynamic>.from(item));
          if (station.playableUrl.isNotEmpty && station.name.isNotEmpty) {
            incoming.add(station);
          }
        }
      }

      if (decoded.isNotEmpty && incoming.isEmpty) return -1;

      int addedCount = 0;
      final List<Station> merged = [...state];
      for (final station in incoming) {
        final alreadyExists = merged.any((s) =>
            s.playableUrl == station.playableUrl ||
            (s.id.isNotEmpty && s.id == station.id));
        if (!alreadyExists) {
          merged.add(station);
          addedCount++;
        }
      }

      if (addedCount > 0) {
        state = merged;
        await _persist();
      }
      return addedCount;
    } catch (_) {
      return -1;
    }
  }
}
