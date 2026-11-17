import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:myradio1/models/station.dart';
import 'package:myradio1/providers/audio_handler_provider.dart';
import 'package:myradio1/providers/countries_provider.dart';
import 'package:myradio1/providers/favorites_provider.dart';
import 'package:myradio1/providers/localization_provider.dart';
import 'package:myradio1/providers/recent_stations_provider.dart';
import 'package:myradio1/providers/recording_provider.dart';
import 'package:myradio1/screens/add_station_screen.dart';
import 'package:myradio1/screens/drive_mode_screen.dart';
import 'package:myradio1/services/app_audio_handler.dart';
import 'package:myradio1/services/share_service.dart';
import 'package:myradio1/theme/app_theme.dart';
import 'package:myradio1/utils/country_names.dart';
import 'package:myradio1/widgets/app_drawer.dart';
import 'package:myradio1/widgets/country_picker_sheet.dart';
import 'package:myradio1/widgets/station_card.dart';
import 'package:myradio1/widgets/mini_player.dart';
import 'package:myradio1/widgets/full_player.dart';

export 'package:myradio1/providers/audio_handler_provider.dart' show currentStationProvider;

class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});

  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Station> _stations = [];
  List<Station> _trendingStations = [];
  String? _selectedCountry;
  String? _selectedCountryCode;
  String _selectedCategoryKey = 'cat_all';
  bool _isLoadingStations = false;
  bool _isLoadingTrending = false;
  bool _stationsError = false;
  bool _trendingError = false;

  static const _mirrors = [
    'https://all.api.radio-browser.info',
    'https://de1.api.radio-browser.info',
  ];

  final List<Map<String, String>> _categories = const [
    {'key': 'cat_all', 'tag': ''},
    {'key': 'cat_quran', 'tag': 'quran'},
    {'key': 'cat_news', 'tag': 'news'},
    {'key': 'cat_talk', 'tag': 'talk'},
    {'key': 'cat_classical', 'tag': 'classical'},
    {'key': 'cat_music', 'tag': 'music'},
    {'key': 'cat_sports', 'tag': 'sports'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchTrendingStations();
    _fetchGlobalStations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Station> _mapAndPrioritizeStations(List<dynamic> data) {
    final working = <Station>[];
    final others = <Station>[];
    for (final item in data) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final station = Station.fromMap(map);
      final ok = map['lastcheckok'];
      if (ok == 1 || ok == true || ok == '1') {
        working.add(station);
      } else {
        others.add(station);
      }
    }
    return [...working, ...others];
  }

  Future<List<dynamic>?> _getFromMirrors(String path) async {
    for (final base in _mirrors) {
      try {
        final res = await http
            .get(Uri.parse('$base$path'))
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          return json.decode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        }
      } catch (_) {
        // Fallback to next mirror
      }
    }
    return null;
  }

  Future<void> _fetchTrendingStations() async {
    setState(() {
      _isLoadingTrending = true;
      _trendingError = false;
    });
    final data = await _getFromMirrors('/json/stations/topvote/35');
    if (!mounted) return;
    setState(() {
      if (data != null) {
        _trendingStations = _mapAndPrioritizeStations(data);
      } else {
        _trendingError = _trendingStations.isEmpty;
      }
      _isLoadingTrending = false;
    });
  }

  Future<void> _fetchGlobalStations() async {
    setState(() {
      _isLoadingStations = true;
      _stationsError = false;
    });
    final data = await _getFromMirrors('/json/stations/search?order=clickcount&reverse=true&limit=60');
    if (!mounted) return;
    setState(() {
      if (data != null) {
        _stations = _mapAndPrioritizeStations(data);
      } else {
        _stationsError = true;
      }
      _isLoadingStations = false;
    });
  }

  Future<void> _fetchDefaultExploreStations() {
    if (_selectedCountry != null) {
      return _fetchStationsByCountry(_selectedCountry!);
    }
    return _fetchGlobalStations();
  }

  Future<void> _fetchStationsByCountry(String country) async {
    setState(() {
      _isLoadingStations = true;
      _stationsError = false;
    });
    final data = await _getFromMirrors(
      '/json/stations/bycountry/${Uri.encodeComponent(country)}?order=votes&reverse=true&limit=100',
    );
    if (!mounted) return;
    setState(() {
      if (data != null) {
        _stations = _mapAndPrioritizeStations(data);
      } else {
        _stationsError = true;
      }
      _isLoadingStations = false;
    });
  }

  Future<void> _fetchStationsByTag(String tag) async {
    if (tag.isEmpty) {
      await _fetchDefaultExploreStations();
      return;
    }
    setState(() {
      _isLoadingStations = true;
      _stationsError = false;
    });
    final data = await _getFromMirrors(
      '/json/stations/bytag/${Uri.encodeComponent(tag)}?order=votes&reverse=true&limit=50',
    );
    if (!mounted) return;
    setState(() {
      if (data != null) {
        _stations = _mapAndPrioritizeStations(data);
      } else {
        _stationsError = true;
      }
      _isLoadingStations = false;
    });
  }

  Future<void> _searchStations(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoadingStations = true;
      _stationsError = false;
    });
    final data = await _getFromMirrors(
      '/json/stations/byname/${Uri.encodeComponent(query.trim())}?order=votes&reverse=true&limit=80',
    );
    if (!mounted) return;
    setState(() {
      if (data != null) {
        _stations = _mapAndPrioritizeStations(data);
      } else {
        _stationsError = true;
      }
      _isLoadingStations = false;
    });
  }

  void _clearCountryFilter() {
    setState(() {
      _selectedCountry = null;
      _selectedCountryCode = null;
      _selectedCategoryKey = 'cat_all';
      _searchController.clear();
    });
    _fetchGlobalStations();
  }

  Future<void> _toggleStreamRecording(Station station, String lang) async {
    final result = await ref.read(recordingProvider.notifier).toggleRecording(
          streamUrl: station.playableUrl,
          stationName: station.name,
        );
    if (!mounted) return;
    if (result == 'started') {
      _showSnackBar(AppStrings.get('recording_started', lang));
    } else if (result == 'stopped') {
      _showSnackBar(AppStrings.get('recording_saved', lang));
    } else {
      _showSnackBar(AppStrings.get('record_not_supported', lang));
    }
  }

  void _playStation(AppAudioHandler audioHandler, Station station) {
    ref.read(currentStationProvider.notifier).state = station;
    ref.read(recentStationsProvider.notifier).addStation(station);
    audioHandler.playFromUrl(
      station.playableUrl,
      title: station.name,
      artist: station.country,
      artUri: station.favicon,
    );
  }

  void _openFullPlayer(AppAudioHandler audioHandler, Station station, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FullPlayer(
        station: station,
        audioHandler: audioHandler,
        onClose: () => Navigator.pop(ctx),
        onToggleRecord: () => _toggleStreamRecording(station, lang),
      ),
    );
  }

  void _openDriveMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriveModeScreen(
          fallbackPlaylist: _stations.isNotEmpty ? _stations : _trendingStations,
        ),
      ),
    );
  }

  Future<void> _backupFavorites(String lang) async {
    final jsonBackup = ref.read(favoritesProvider.notifier).exportFavoritesJson();
    final shared = await ShareService.shareText(
      jsonBackup,
      subject: AppStrings.get('backup_favorites', lang),
    );
    if (!shared) {
      await Clipboard.setData(ClipboardData(text: jsonBackup));
      if (mounted) {
        _showSnackBar(AppStrings.get('backup_copied', lang));
      }
    }
  }

  Future<void> _showRestoreDialog(String lang) async {
    final controller = TextEditingController();
    final isRtl = lang == 'ar';
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(AppStrings.get('restore_favorites', lang)),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: AppStrings.get('paste_backup_hint', lang),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.get('cancel', lang)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final count = await ref
                    .read(favoritesProvider.notifier)
                    .importFavoritesJson(controller.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (count >= 0) {
                  _showSnackBar('${AppStrings.get('backup_restored', lang)} ($count)');
                } else {
                  _showSnackBar(AppStrings.get('backup_invalid', lang));
                }
              },
              child: Text(AppStrings.get('restore_favorites', lang)),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  void _retryExploreLoad() {
    if (_searchController.text.trim().isNotEmpty) {
      _searchStations(_searchController.text);
    } else if (_selectedCategoryKey != 'cat_all') {
      final tag = _categories.firstWhere((c) => c['key'] == _selectedCategoryKey)['tag'] ?? '';
      _fetchStationsByTag(tag);
    } else {
      _fetchDefaultExploreStations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioHandlerAsync = ref.watch(audioHandlerProvider);
    final favorites = ref.watch(favoritesProvider);
    final currentStation = ref.watch(currentStationProvider);
    final lang = ref.watch(localeProvider);
    final isRtl = lang == 'ar';

    return audioHandlerAsync.when(
      data: (audioHandler) => StreamBuilder<PlaybackState>(
        stream: audioHandler.playbackState,
        builder: (context, snapshot) {
          final playbackState = snapshot.data;
          final isPlaying = playbackState?.playing ?? false;
          final isLoading = playbackState?.processingState == AudioProcessingState.loading ||
              playbackState?.processingState == AudioProcessingState.buffering;

          return Directionality(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                if (_searchController.text.isNotEmpty) {
                  _searchController.clear();
                  FocusScope.of(context).unfocus();
                  setState(() {});
                  _fetchDefaultExploreStations();
                  return;
                }
                final currentFocus = FocusScope.of(context);
                if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
                  currentFocus.unfocus();
                  return;
                }
                if (_tabController.index != 0) {
                  _tabController.animateTo(0);
                  return;
                }
                final shouldExit = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.surfaceElevated,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text(AppStrings.get('exit_confirm_title', lang)),
                    content: Text(AppStrings.get('exit_confirm_msg', lang)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(AppStrings.get('cancel', lang)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRecord),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(AppStrings.get('exit', lang)),
                      ),
                    ],
                  ),
                );
                if (shouldExit == true) {
                  SystemNavigator.pop();
                }
              },
              child: Scaffold(
                drawer: AppDrawer(
                  onGoHome: () => _tabController.animateTo(0),
                ),
              appBar: AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.radio_rounded, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        AppStrings.get('app_title', lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.directions_car_rounded),
                    tooltip: AppStrings.get('drive_mode', lang),
                    onPressed: _openDriveMode,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: AppStrings.get('retry', lang),
                    onPressed: () {
                      ref.read(countriesProvider.notifier).fetchCountries();
                      _fetchTrendingStations();
                      _retryExploreLoad();
                    },
                  ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.explore_outlined),
                      text: AppStrings.get('explore', lang),
                    ),
                    Tab(
                      icon: const Icon(Icons.local_fire_department_outlined),
                      text: AppStrings.get('trending', lang),
                    ),
                    Tab(
                      icon: const Icon(Icons.favorite_outline_rounded),
                      text: '${AppStrings.get('favorites', lang)} (${favorites.length})',
                    ),
                  ],
                ),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildExploreTab(audioHandler, currentStation, isPlaying, lang),
                        _buildTrendingTab(audioHandler, currentStation, isPlaying, lang),
                        _buildFavoritesTab(audioHandler, favorites, currentStation, isPlaying, lang),
                      ],
                    ),
                  ),
                  if (currentStation != null)
                    MiniPlayer(
                      station: currentStation,
                      isPlaying: isPlaying,
                      isLoading: isLoading,
                      audioHandler: audioHandler,
                      lang: lang,
                      onExpand: () => _openFullPlayer(audioHandler, currentStation, lang),
                      onClose: () {
                        FocusScope.of(context).unfocus();
                        audioHandler.stop();
                        ref.read(currentStationProvider.notifier).state = null;
                      },
                    ),
                ],
              ),
            ),
          ),
        );
        },
      ),
      error: (err, s) => Scaffold(
        body: Center(child: Text('$err', style: const TextStyle(color: Colors.red))),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      ),
    );
  }

  Widget _buildExploreTab(AppAudioHandler audioHandler, Station? currentStation, bool isPlaying, String lang) {
    final recentStations = ref.watch(recentStationsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: AppStrings.get('search_hint', lang),
              prefixIcon: IconButton(
                icon: const Icon(Icons.search, color: AppTheme.textMuted),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _searchStations(_searchController.text);
                },
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _fetchDefaultExploreStations();
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: _searchStations,
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategoryKey == cat['key'];
              return ChoiceChip(
                label: Text(AppStrings.get(cat['key']!, lang)),
                selected: isSelected,
                selectedColor: AppTheme.primary,
                backgroundColor: Theme.of(context).cardColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                  width: 1,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedCategoryKey = cat['key']!);
                    _fetchStationsByTag(cat['tag']!);
                  }
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showCountryPickerModal(lang),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedCountry != null
                      ? AppTheme.primary.withValues(alpha: 0.5)
                      : AppTheme.border,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.public, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedCountry != null
                          ? '${AppStrings.get('country_label', lang)}: ${CountryNames.getDisplayName(_selectedCountryCode, _selectedCountry!, lang)}'
                          : '${AppStrings.get('country_label', lang)}: ${AppStrings.get('all_countries', lang)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedCountry != null ? FontWeight.w600 : FontWeight.normal,
                        color: _selectedCountry != null ? AppTheme.primary : null,
                      ),
                    ),
                  ),
                  if (_selectedCountry != null)
                    IconButton(
                      tooltip: AppStrings.get('clear_country_filter', lang),
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 18),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: _clearCountryFilter,
                    ),
                  const Icon(Icons.arrow_drop_down, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
        ),
        if (recentStations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history_rounded, size: 15, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            AppStrings.get('recently_played', lang),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => ref.read(recentStationsProvider.notifier).clearAll(),
                        child: Text(
                          AppStrings.get('clear', lang),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recentStations.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final st = recentStations[index];
                      final isCurr = currentStation?.playableUrl == st.playableUrl;
                      return ActionChip(
                        avatar: Icon(
                          isCurr && isPlaying ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                          size: 16,
                          color: isCurr ? AppTheme.primary : AppTheme.textMuted,
                        ),
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            st.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isCurr ? AppTheme.primary : null,
                              fontWeight: isCurr ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        backgroundColor: Theme.of(context).cardColor,
                        side: BorderSide(
                          color: isCurr ? AppTheme.primary : AppTheme.border,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        onPressed: () => _playStation(audioHandler, st),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _isLoadingStations
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : (_stationsError && _stations.isEmpty)
                  ? _buildEmptyState(
                      AppStrings.get('network_error_stations', lang),
                      actionLabel: AppStrings.get('retry', lang),
                      onAction: _retryExploreLoad,
                    )
                  : _stations.isEmpty
                      ? _buildEmptyState(AppStrings.get('no_stations', lang))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20, top: 4),
                          itemCount: _stations.length,
                          itemBuilder: (context, index) {
                            final station = _stations[index];
                            final isCurrent = currentStation?.streamUrl == station.streamUrl;
                            return StationCard(
                              station: station,
                              isCurrent: isCurrent,
                              isPlaying: isCurrent && isPlaying,
                              onTap: () => _playStation(audioHandler, station),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildTrendingTab(AppAudioHandler audioHandler, Station? currentStation, bool isPlaying, String lang) {
    if (_isLoadingTrending) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_trendingError && _trendingStations.isEmpty) {
      return _buildEmptyState(
        AppStrings.get('network_error_stations', lang),
        actionLabel: AppStrings.get('retry', lang),
        onAction: _fetchTrendingStations,
      );
    }

    if (_trendingStations.isEmpty) {
      return _buildEmptyState(AppStrings.get('loading_trending', lang));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      itemCount: _trendingStations.length,
      itemBuilder: (context, index) {
        final station = _trendingStations[index];
        final isCurrent = currentStation?.streamUrl == station.streamUrl;
        return StationCard(
          station: station,
          isCurrent: isCurrent,
          isPlaying: isCurrent && isPlaying,
          onTap: () => _playStation(audioHandler, station),
        );
      },
    );
  }

  Widget _buildFavoritesTab(AppAudioHandler audioHandler, List<Station> favorites, Station? currentStation, bool isPlaying, String lang) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 17, color: AppTheme.primary),
                label: Text(AppStrings.get('add_custom_station', lang), style: const TextStyle(fontSize: 12)),
                backgroundColor: Theme.of(context).cardColor,
                side: const BorderSide(color: AppTheme.border),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddStationScreen()),
                  );
                },
              ),
              if (favorites.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.upload_rounded, size: 16, color: AppTheme.secondary),
                  label: Text(AppStrings.get('backup_favorites', lang), style: const TextStyle(fontSize: 12)),
                  backgroundColor: Theme.of(context).cardColor,
                  side: const BorderSide(color: AppTheme.border),
                  onPressed: () => _backupFavorites(lang),
                ),
              ActionChip(
                avatar: const Icon(Icons.download_rounded, size: 16, color: AppTheme.accentLive),
                label: Text(AppStrings.get('restore_favorites', lang), style: const TextStyle(fontSize: 12)),
                backgroundColor: Theme.of(context).cardColor,
                side: const BorderSide(color: AppTheme.border),
                onPressed: () => _showRestoreDialog(lang),
              ),
            ],
          ),
        ),
        Expanded(
          child: favorites.isEmpty
              ? _buildEmptyState(AppStrings.get('empty_favorites', lang))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20, top: 6),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final station = favorites[index];
                    final isCurrent = currentStation?.streamUrl == station.streamUrl;
                    return StationCard(
                      station: station,
                      isCurrent: isCurrent,
                      isPlaying: isCurrent && isPlaying,
                      onTap: () => _playStation(audioHandler, station),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, {String? actionLabel, VoidCallback? onAction}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radio_outlined, size: 54, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCountryPickerModal(String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CountryPickerSheet(
        selectedCountry: _selectedCountry,
        lang: lang,
        onSelect: (countryName, isoCode) {
          setState(() {
            _selectedCountry = countryName;
            _selectedCountryCode = isoCode;
            _selectedCategoryKey = 'cat_all';
            _searchController.clear();
          });
          _fetchDefaultExploreStations();
        },
      ),
    );
  }

  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
