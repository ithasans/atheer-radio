import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myradio1/providers/countries_provider.dart';
import 'package:myradio1/providers/localization_provider.dart';
import 'package:myradio1/theme/app_theme.dart';
import 'package:myradio1/utils/country_names.dart';

class CountryPickerSheet extends ConsumerStatefulWidget {
  final String? selectedCountry;
  final String lang;
  final void Function(String? countryName, String? isoCode) onSelect;

  const CountryPickerSheet({
    super.key,
    required this.selectedCountry,
    required this.lang,
    required this.onSelect,
  });

  @override
  ConsumerState<CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends ConsumerState<CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(countriesProvider);
      if (state.countries.isEmpty && !state.isLoading) {
        ref.read(countriesProvider.notifier).fetchCountries();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _submitSearch(String value) {
    setState(() {
      _query = value;
    });
    _searchFocusNode.unfocus();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
    });
  }

  List<Map<String, dynamic>> _buildFilteredList(List<dynamic> countries) {
    final trimmed = _query.trim();
    final List<MapEntry<Map<String, dynamic>, int>> scored = [];

    for (final item in countries) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final name = (map['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final score = CountryNames.matchScore(map, trimmed);
      if (score > 0) {
        scored.add(MapEntry(map, score));
      }
    }

    scored.sort((a, b) {
      if (trimmed.isNotEmpty && a.value != b.value) {
        return b.value.compareTo(a.value);
      }
      final nameA = CountryNames.getDisplayName(
        (a.key['iso_3166_1'] ?? '').toString(),
        (a.key['name'] ?? '').toString(),
        widget.lang,
      );
      final nameB = CountryNames.getDisplayName(
        (b.key['iso_3166_1'] ?? '').toString(),
        (b.key['name'] ?? '').toString(),
        widget.lang,
      );
      return CountryNames.normalize(nameA).compareTo(CountryNames.normalize(nameB));
    });

    return scored.map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final countriesState = ref.watch(countriesProvider);
    final isRtl = widget.lang == 'ar';
    final filteredCountries = _buildFilteredList(countriesState.countries);

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final availableHeight = (mediaQuery.size.height - mediaQuery.padding.top - bottomInset - 12)
        .clamp(180.0, mediaQuery.size.height);
    final sheetHeight = math.min(availableHeight, mediaQuery.size.height * 0.82);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: sheetHeight,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    AppStrings.get('select_country', widget.lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: AppStrings.get('search_country_hint', widget.lang),
                      prefixIcon: IconButton(
                        tooltip: AppStrings.get('select_country', widget.lang),
                        icon: const Icon(Icons.search, color: AppTheme.primary),
                        onPressed: () => _submitSearch(_searchController.text),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              tooltip: AppStrings.get('clear_search', widget.lang),
                              icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                              onPressed: _clearSearch,
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _query = val),
                    onSubmitted: _submitSearch,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _buildBody(context, countriesState, filteredCountries),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CountriesState countriesState,
    List<Map<String, dynamic>> filteredCountries,
  ) {
    if (countriesState.isLoading && countriesState.countries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (countriesState.countries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              Text(
                AppStrings.get('countries_load_error', widget.lang),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(countriesProvider.notifier).fetchCountries(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(AppStrings.get('retry', widget.lang)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredCountries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              Text(
                AppStrings.get('no_countries_found', widget.lang),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: Text(AppStrings.get('clear_search', widget.lang)),
              ),
            ],
          ),
        ),
      );
    }

    final showAllTile = _query.trim().isEmpty;

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: filteredCountries.length + (showAllTile ? 1 : 0),
      itemBuilder: (context, index) {
        if (showAllTile && index == 0) {
          final isAllSelected = widget.selectedCountry == null;
          return ListTile(
            leading: Icon(
              Icons.public_rounded,
              color: isAllSelected ? AppTheme.primary : AppTheme.textMuted,
            ),
            title: Text(
              AppStrings.get('all_countries', widget.lang),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isAllSelected ? AppTheme.primary : null,
                fontWeight: isAllSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            trailing: isAllSelected
                ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18)
                : null,
            onTap: () {
              widget.onSelect(null, null);
              Navigator.pop(context);
            },
          );
        }

        final country = filteredCountries[showAllTile ? index - 1 : index];
        final apiName = (country['name'] ?? '').toString();
        final iso = (country['iso_3166_1'] ?? '').toString();
        final stationCount = country['stationcount'] ?? 0;
        final isSelected = widget.selectedCountry == apiName;

        final displayName = CountryNames.getDisplayName(iso, apiName, widget.lang);
        final showSubtitle = widget.lang == 'ar' && displayName != apiName;

        return ListTile(
          title: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? AppTheme.primary : null,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: showSubtitle
              ? Text(
                  apiName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.5) : Colors.transparent,
                  ),
                ),
                child: Text(
                  '$stationCount ${AppStrings.get('station_count', widget.lang)}',
                  style: TextStyle(
                    color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
              ],
            ],
          ),
          onTap: () {
            widget.onSelect(apiName, iso);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
