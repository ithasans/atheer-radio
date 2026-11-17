import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myradio1/models/station.dart';
import 'package:myradio1/providers/audio_handler_provider.dart';
import 'package:myradio1/providers/favorites_provider.dart';
import 'package:myradio1/providers/localization_provider.dart';
import 'package:myradio1/providers/recent_stations_provider.dart';
import 'package:myradio1/services/app_audio_handler.dart';
import 'package:myradio1/theme/app_theme.dart';
import 'package:myradio1/utils/encoding_utils.dart';
import 'package:myradio1/widgets/audio_visualizer.dart';

class DriveModeScreen extends ConsumerWidget {
  final List<Station> fallbackPlaylist;

  const DriveModeScreen({
    super.key,
    this.fallbackPlaylist = const [],
  });

  List<Station> _buildPlaylist(List<Station> favorites, List<Station> recent) {
    final List<Station> combined = [];
    final Set<String> seenUrls = {};
    for (final s in [...favorites, ...recent, ...fallbackPlaylist]) {
      if (seenUrls.add(s.playableUrl)) {
        combined.add(s);
      }
    }
    return combined;
  }

  void _switchStation(
    WidgetRef ref,
    AppAudioHandler audioHandler,
    List<Station> playlist,
    Station? current,
    int delta,
  ) {
    if (playlist.isEmpty) return;
    int idx = current == null
        ? 0
        : playlist.indexWhere((s) => s.playableUrl == current.playableUrl);
    if (idx < 0) idx = 0;
    final nextIdx = (idx + delta) % playlist.length;
    final target = playlist[nextIdx < 0 ? nextIdx + playlist.length : nextIdx];
    ref.read(currentStationProvider.notifier).state = target;
    ref.read(recentStationsProvider.notifier).addStation(target);
    audioHandler.playFromUrl(
      target.playableUrl,
      title: target.name,
      artist: target.country,
      artUri: target.favicon,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final isRtl = lang == 'ar';
    final currentStation = ref.watch(currentStationProvider);
    final favorites = ref.watch(favoritesProvider);
    final recent = ref.watch(recentStationsProvider);
    final audioHandlerAsync = ref.watch(audioHandlerProvider);
    final playlist = _buildPlaylist(favorites, recent);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 28, color: Colors.white),
            tooltip: AppStrings.get('exit_drive_mode', lang),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_car_rounded, color: AppTheme.primary, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  AppStrings.get('drive_mode', lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: audioHandlerAsync.when(
            data: (audioHandler) => StreamBuilder<PlaybackState>(
              stream: audioHandler.playbackState,
              builder: (context, stateSnap) {
                final playbackState = stateSnap.data;
                final isPlaying = playbackState?.playing ?? false;
                final processing = playbackState?.processingState ?? AudioProcessingState.idle;
                final isLoading = processing == AudioProcessingState.loading ||
                    processing == AudioProcessingState.buffering;
                final isLive = isPlaying && !isLoading;

                return StreamBuilder<MediaItem?>(
                  stream: audioHandler.mediaItem,
                  builder: (context, mediaSnap) {
                    final media = mediaSnap.data;
                    final rawIcy = (media?.extras?['icyTitle'] ?? '').toString().trim();
                    final icyTitle = EncodingUtils.decodeStreamMetadata(rawIcy);

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Station Header Card
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isLive
                                            ? AppTheme.primary.withValues(alpha: 0.7)
                                            : AppTheme.border,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isLive ? AppTheme.accentLive : AppTheme.textMuted,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isLive
                                                  ? AppStrings.get('live_stream', lang)
                                                  : AppStrings.get('stop', lang),
                                              style: TextStyle(
                                                color: isLive ? AppTheme.accentLive : AppTheme.textMuted,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          currentStation?.name ?? AppStrings.get('no_station_playing', lang),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (icyTitle.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Text(
                                              '${AppStrings.get('now_playing', lang)}: $icyTitle',
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppTheme.primary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ] else if (currentStation?.country != null &&
                                            currentStation!.country!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            currentStation.country!,
                                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                                          ),
                                        ],
                                        const SizedBox(height: 18),
                                        AudioVisualizer(
                                          isPlaying: isLive,
                                          barCount: 11,
                                          maxHeight: 30,
                                          width: 4,
                                          color: AppTheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Giant Touch Transport Controls
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _driveRoundButton(
                                        icon: Icons.skip_previous_rounded,
                                        label: AppStrings.get('previous_station', lang),
                                        size: 74,
                                        iconSize: 42,
                                        onTap: playlist.isEmpty
                                            ? null
                                            : () => _switchStation(ref, audioHandler, playlist, currentStation, -1),
                                      ),
                                      Container(
                                        width: 112,
                                        height: 112,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: AppTheme.primaryGradient,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primary.withValues(alpha: 0.45),
                                              blurRadius: 24,
                                            ),
                                          ],
                                        ),
                                        child: isLoading
                                            ? const Center(
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 3.5,
                                                ),
                                              )
                                            : IconButton(
                                                iconSize: 64,
                                                icon: Icon(
                                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                  color: Colors.white,
                                                ),
                                                onPressed: () {
                                                  if (isPlaying) {
                                                    audioHandler.pause();
                                                  } else if (currentStation != null) {
                                                    audioHandler.playFromUrl(
                                                      currentStation.playableUrl,
                                                      title: currentStation.name,
                                                      artist: currentStation.country,
                                                      artUri: currentStation.favicon,
                                                    );
                                                  } else if (playlist.isNotEmpty) {
                                                    _switchStation(ref, audioHandler, playlist, null, 0);
                                                  }
                                                },
                                              ),
                                      ),
                                      _driveRoundButton(
                                        icon: Icons.skip_next_rounded,
                                        label: AppStrings.get('next_station', lang),
                                        size: 74,
                                        iconSize: 42,
                                        onTap: playlist.isEmpty
                                            ? null
                                            : () => _switchStation(ref, audioHandler, playlist, currentStation, 1),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 24),

                                  // Large Exit Drive Mode Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 58,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: AppTheme.border, width: 1.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.fullscreen_exit_rounded, size: 24),
                                      label: Text(
                                        AppStrings.get('exit_drive_mode', lang),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
          ),
        ),
      ),
    );
  }

  Widget _driveRoundButton({
    required IconData icon,
    required String label,
    required double size,
    required double iconSize,
    required VoidCallback? onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surfaceElevated,
            border: Border.all(color: AppTheme.border, width: 1.5),
          ),
          child: IconButton(
            iconSize: iconSize,
            icon: Icon(icon, color: onTap == null ? AppTheme.textMuted : Colors.white),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
