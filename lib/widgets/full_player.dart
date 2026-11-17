import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:myradio1/models/station.dart';
import 'package:myradio1/providers/favorites_provider.dart';
import 'package:myradio1/providers/localization_provider.dart';
import 'package:myradio1/providers/recording_provider.dart';
import 'package:myradio1/providers/sleep_timer_provider.dart';
import 'package:myradio1/screens/drive_mode_screen.dart';
import 'package:myradio1/services/app_audio_handler.dart';
import 'package:myradio1/services/share_service.dart';
import 'package:myradio1/theme/app_theme.dart';
import 'package:myradio1/utils/encoding_utils.dart';
import 'package:myradio1/widgets/audio_visualizer.dart';
import 'package:myradio1/widgets/equalizer_sheet.dart';
import 'package:myradio1/widgets/station_avatar.dart';

class FullPlayer extends ConsumerStatefulWidget {
  final Station station;
  final AppAudioHandler audioHandler;
  final VoidCallback onClose;
  final VoidCallback onToggleRecord;

  const FullPlayer({
    super.key,
    required this.station,
    required this.audioHandler,
    required this.onClose,
    required this.onToggleRecord,
    bool? isPlaying,
    bool? isLoading,
    bool? isRecording,
  });

  @override
  ConsumerState<FullPlayer> createState() => _FullPlayerState();
}

class _FullPlayerState extends ConsumerState<FullPlayer> {
  double _volume = 1.0;

  void _showSleepTimerPicker(String lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final timerState = ref.watch(sleepTimerProvider);
        final isRtl = lang == 'ar';

        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  AppStrings.get('sleep_timer', lang),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (timerState.isActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${AppStrings.get('remaining', lang)}: ${timerState.formattedRemaining}',
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(sleepTimerProvider.notifier).cancelTimer();
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            AppStrings.get('cancel_timer', lang),
                            style: const TextStyle(color: AppTheme.accentRecord),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [15, 30, 45, 60, 90].map((mins) {
                    return ActionChip(
                      label: Text('$mins ${AppStrings.get('minutes', lang)}'),
                      backgroundColor: AppTheme.surfaceElevated,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onPressed: () {
                        ref.read(sleepTimerProvider.notifier).startTimer(mins);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${AppStrings.get('sleep_timer_set', lang)} ($mins ${AppStrings.get('minutes', lang)})')),
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openEqualizer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EqualizerSheet(audioHandler: widget.audioHandler),
    );
  }

  Future<void> _shareStation(String lang) async {
    final appName = AppStrings.get('app_title', lang);
    final shareText = '${widget.station.name}\n$appName\n${widget.station.playableUrl}';
    final shared = await ShareService.shareText(shareText, subject: widget.station.name);
    if (!shared && mounted) {
      await Clipboard.setData(ClipboardData(text: shareText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('copied', lang))),
        );
      }
    }
  }

  void _handlePlayAction(bool isPlaying, bool isStopped) {
    if (isPlaying) {
      widget.audioHandler.pause();
    } else {
      widget.audioHandler.playFromUrl(
        widget.station.playableUrl,
        title: widget.station.name,
        artist: widget.station.country,
        artUri: widget.station.favicon,
      );
    }
  }

  void _handleStopAction(bool isStopped) {
    if (isStopped) {
      widget.audioHandler.playFromUrl(
        widget.station.playableUrl,
        title: widget.station.name,
        artist: widget.station.country,
        artUri: widget.station.favicon,
      );
    } else {
      widget.audioHandler.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final lang = ref.watch(localeProvider);
    final timerState = ref.watch(sleepTimerProvider);
    final recState = ref.watch(recordingProvider);
    final isRecording = recState.isRecording;
    final isFav = favorites.any((s) => s.streamUrl == widget.station.streamUrl || (s.id.isNotEmpty && s.id == widget.station.id));
    final isRtl = lang == 'ar';

    return StreamBuilder<PlaybackState>(
      stream: widget.audioHandler.playbackState,
      builder: (context, snapshot) {
        final playbackState = snapshot.data;
        final isPlaying = playbackState?.playing ?? false;
        final processingState = playbackState?.processingState ?? AudioProcessingState.idle;
        final isLoading = processingState == AudioProcessingState.loading || processingState == AudioProcessingState.buffering;
        final isStopped = processingState == AudioProcessingState.idle;
        final isLivePlaying = isPlaying && !isLoading;

        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxHeight < 680;
                  final avatarSize = isCompact ? 124.0 : 172.0;

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Top Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                                  onPressed: widget.onClose,
                                ),
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isLivePlaying ? AppTheme.accentLive : AppTheme.textMuted,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          isLivePlaying
                                              ? AppStrings.get('live_stream', lang)
                                              : (isStopped ? AppStrings.get('stop', lang) : AppStrings.get('pause', lang)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isLivePlaying ? AppTheme.accentLive : AppTheme.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.timer_outlined,
                                            color: timerState.isActive ? AppTheme.primary : AppTheme.textMuted,
                                            size: 24,
                                          ),
                                          onPressed: () => _showSleepTimerPicker(lang),
                                        ),
                                        if (timerState.isActive)
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isFav ? Icons.favorite : Icons.favorite_border,
                                        color: isFav ? Colors.redAccent : AppTheme.textMuted,
                                        size: 24,
                                      ),
                                      onPressed: () {
                                        ref.read(favoritesProvider.notifier).toggleFavorite(widget.station);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(height: isCompact ? 8 : 16),

                            // Station Artwork
                            Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (isLivePlaying)
                                    Container(
                                      width: avatarSize + 30,
                                      height: avatarSize + 30,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primary.withValues(alpha: 0.25),
                                            blurRadius: 36,
                                            spreadRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  StationAvatar(
                                    station: widget.station,
                                    size: avatarSize,
                                    isCurrent: true,
                                    isPlaying: isLivePlaying,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: isCompact ? 12 : 18),

                            // Station Name, Live ICY Track & Tags
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Column(
                                children: [
                                  Text(
                                    widget.station.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isCompact ? 18 : 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  StreamBuilder<MediaItem?>(
                                    stream: widget.audioHandler.mediaItem,
                                    builder: (context, mediaSnap) {
                                      final media = mediaSnap.data;
                                      final matchesStation = media?.id == widget.station.playableUrl;
                                      final rawIcy = matchesStation
                                          ? (media?.extras?['icyTitle'] ?? '').toString().trim()
                                          : '';
                                      final icyTitle = EncodingUtils.decodeStreamMetadata(rawIcy);
                                      if (icyTitle.isEmpty) return const SizedBox.shrink();

                                      return Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.music_note_rounded, size: 15, color: AppTheme.primary),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                '${AppStrings.get('now_playing', lang)}: $icyTitle',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppTheme.primary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      if (widget.station.country != null && widget.station.country!.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.public, size: 14, color: AppTheme.textMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              widget.station.country!,
                                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                            ),
                                          ],
                                        ),
                                      if (widget.station.codec != null && widget.station.codec!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceElevated,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.border),
                                          ),
                                          child: Text(
                                            widget.station.codec!.toUpperCase(),
                                            style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      if (widget.station.bitrate != null && widget.station.bitrate! > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceElevated,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.border),
                                          ),
                                          child: Text(
                                            '${widget.station.bitrate} kbps',
                                            style: const TextStyle(color: AppTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: isCompact ? 10 : 14),

                            // Live Waveform Visualizer
                            AudioVisualizer(
                              isPlaying: isLivePlaying,
                              barCount: 9,
                              maxHeight: isCompact ? 20 : 26,
                              width: 3.2,
                              color: AppTheme.primary,
                            ),

                            if (isRecording) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentRecord.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.accentRecord.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.accentRecord,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${AppStrings.get('recording_live_banner', lang)} • ${recState.formattedElapsed}',
                                      style: const TextStyle(
                                        color: AppTheme.accentRecord,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            SizedBox(height: isCompact ? 10 : 14),

                            // Utility Chips Bar: Equalizer | Drive Mode | Share
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: [
                                _utilityPill(
                                  icon: Icons.equalizer_rounded,
                                  label: AppStrings.get('equalizer', lang),
                                  onTap: _openEqualizer,
                                ),
                                _utilityPill(
                                  icon: Icons.directions_car_rounded,
                                  label: AppStrings.get('drive_mode', lang),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const DriveModeScreen()),
                                    );
                                  },
                                ),
                                _utilityPill(
                                  icon: Icons.share_rounded,
                                  label: AppStrings.get('share_station', lang),
                                  onTap: () => _shareStation(lang),
                                ),
                              ],
                            ),

                            SizedBox(height: isCompact ? 8 : 12),

                            // Volume Slider
                            Row(
                              children: [
                                const Icon(Icons.volume_mute_rounded, color: AppTheme.textMuted, size: 20),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: AppTheme.primary,
                                      inactiveTrackColor: AppTheme.surfaceElevated,
                                      thumbColor: Colors.white,
                                      trackHeight: 3.5,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    ),
                                    child: Slider(
                                      value: _volume,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (val) {
                                        setState(() => _volume = val);
                                        widget.audioHandler.setVolume(val);
                                      },
                                    ),
                                  ),
                                ),
                                const Icon(Icons.volume_up_rounded, color: AppTheme.textMuted, size: 20),
                              ],
                            ),

                            SizedBox(height: isCompact ? 8 : 14),

                            // Playback Controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Record Button
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isRecording
                                            ? AppTheme.accentRecord.withValues(alpha: 0.3)
                                            : AppTheme.surfaceElevated,
                                        border: Border.all(
                                          color: isRecording ? AppTheme.accentRecord : AppTheme.border,
                                          width: isRecording ? 2.5 : 1.5,
                                        ),
                                        boxShadow: isRecording
                                            ? [
                                                BoxShadow(
                                                  color: AppTheme.accentRecord.withValues(alpha: 0.4),
                                                  blurRadius: 14,
                                                  spreadRadius: 2,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: IconButton(
                                        iconSize: 26,
                                        icon: Icon(
                                          isRecording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
                                          color: isRecording ? AppTheme.accentRecord : Colors.redAccent,
                                        ),
                                        onPressed: widget.onToggleRecord,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isRecording ? AppStrings.get('stop_record', lang) : AppStrings.get('record', lang),
                                      style: TextStyle(
                                        color: isRecording ? AppTheme.accentRecord : AppTheme.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),

                                // Main Center Play / Pause Button
                                Container(
                                  width: isCompact ? 64 : 74,
                                  height: isCompact ? 64 : 74,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppTheme.primaryGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: isLoading
                                      ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                      : IconButton(
                                          iconSize: isCompact ? 36 : 42,
                                          icon: Icon(
                                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                          ),
                                          onPressed: () => _handlePlayAction(isPlaying, isStopped),
                                        ),
                                ),

                                // Stop / Replay Button
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isStopped ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.surfaceElevated,
                                        border: Border.all(
                                          color: isStopped ? AppTheme.primary : AppTheme.border,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: IconButton(
                                        iconSize: 26,
                                        icon: Icon(
                                          isStopped ? Icons.play_arrow_rounded : Icons.stop_rounded,
                                          color: isStopped ? AppTheme.primary : AppTheme.textSecondary,
                                        ),
                                        onPressed: () => _handleStopAction(isStopped),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isStopped ? AppStrings.get('play', lang) : AppStrings.get('stop', lang),
                                      style: TextStyle(
                                        color: isStopped ? AppTheme.primary : AppTheme.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _utilityPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppTheme.primary),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      backgroundColor: AppTheme.surfaceElevated,
      side: const BorderSide(color: AppTheme.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onTap,
    );
  }
}
