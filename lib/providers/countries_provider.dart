import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class CountriesState {
  final List<dynamic> countries;
  final bool isLoading;
  final bool hasError;

  const CountriesState({
    this.countries = const [],
    this.isLoading = false,
    this.hasError = false,
  });

  CountriesState copyWith({
    List<dynamic>? countries,
    bool? isLoading,
    bool? hasError,
  }) {
    return CountriesState(
      countries: countries ?? this.countries,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
    );
  }
}

final countriesProvider = StateNotifierProvider<CountriesNotifier, CountriesState>((ref) {
  return CountriesNotifier();
});

class CountriesNotifier extends StateNotifier<CountriesState> {
  CountriesNotifier({bool autoFetch = true})
      : super(CountriesState(isLoading: autoFetch)) {
    if (autoFetch) {
      fetchCountries();
    }
  }

  /// Cleans, deduplicates, and sorts the raw countries list from Radio Browser API.
  static List<dynamic> normalizeCountryList(List<dynamic> rawList) {
    final Map<String, Map<String, dynamic>> byName = {};
    for (final item in rawList) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final iso = (item['iso_3166_1'] ?? '').toString().trim().toUpperCase();
      final count = (item['stationcount'] is int)
          ? item['stationcount'] as int
          : int.tryParse((item['stationcount'] ?? '0').toString()) ?? 0;

      final key = name.toLowerCase();
      if (byName.containsKey(key)) {
        final existing = byName[key]!;
        final existingCount = (existing['stationcount'] as int?) ?? 0;
        existing['stationcount'] = existingCount + count;
        if ((existing['iso_3166_1'] ?? '').toString().isEmpty && iso.isNotEmpty) {
          existing['iso_3166_1'] = iso;
        }
      } else {
        byName[key] = {
          'name': name,
          'iso_3166_1': iso,
          'stationcount': count,
        };
      }
    }

    final result = byName.values.toList();
    result.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return result;
  }

  Future<void> fetchCountries() async {
    state = state.copyWith(isLoading: true, hasError: false);
    const urls = [
      'https://all.api.radio-browser.info/json/countries',
      'https://de1.api.radio-browser.info/json/countries',
    ];

    for (final url in urls) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          final List<dynamic> raw = json.decode(utf8.decode(res.bodyBytes));
          final cleaned = normalizeCountryList(raw);
          if (mounted) {
            state = CountriesState(
              countries: cleaned,
              isLoading: false,
              hasError: false,
            );
          }
          return;
        }
      } catch (_) {
        // Try next mirror or mark error below
      }
    }

    if (mounted) {
      state = state.copyWith(
        isLoading: false,
        hasError: state.countries.isEmpty,
      );
    }
  }
}
