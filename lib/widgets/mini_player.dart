import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:myradio1/models/station.dart';
import 'package:myradio1/services/app_audio_handler.dart';
import 'package:myradio1/theme/app_theme.dart';
import 'package:myradio1/widgets/audio_visualizer.dart';
import 'package:myradio1/widgets/station_avatar.dart';

class MiniPlayer extends StatelessWidget {
  final Station station;
  final bool isPlaying;
  final bool isLoading;
  final AppAudioHandler audioHandler;
  final VoidCallback onExpand;

  const MiniPlayer({
    super.key,
    required this.station,
    required this.isPlaying,
    required this.isLoading,
    required this.audioHandler,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final isLivePlaying = isPlaying && !isLoading;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onExpand,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    StationAvatar(
                      station: station,
                      size: 44,
                      isCurrent: true,
                      isPlaying: isLivePlaying,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StreamBuilder<MediaItem?>(
                        stream: audioHandler.mediaItem,
                        builder: (context, mediaSnap) {
                          final media = mediaSnap.data;
                          final matches = media?.id == station.playableUrl;
                          final icyTitle = matches
                              ? (media?.extras?['icyTitle'] ?? '').toString().trim()
                              : '';
                          final subtitle = icyTitle.isNotEmpty
                              ? icyTitle
                              : (station.country ?? (station.tagList.isNotEmpty ? station.tagList.first : 'بث مباشر'));

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      station.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isLivePlaying ? AppTheme.accentLive : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: icyTitle.isNotEmpty ? AppTheme.primary : AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: icyTitle.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: AudioVisualizer(
                        isPlaying: isLivePlaying,
                        maxHeight: 16,
                        width: 2.2,
                        color: AppTheme.primary,
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: AppTheme.primary,
                          size: 36,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            audioHandler.pause();
                          } else {
                            audioHandler.playFromUrl(
                              station.playableUrl,
                              title: station.name,
                              artist: station.country,
                              artUri: station.favicon,
                            );
                          }
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 20),
                      onPressed: () => audioHandler.stop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
